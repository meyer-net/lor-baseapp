-- 自定义函数指针
local type = type
local n_log = ngx.log
local n_err = ngx.ERR
local n_debug = ngx.DEBUG

local s_format = string.format

-- 统一引用导入LIBS
local c_json = require("cjson.safe")
local r_lock = require("resty.lock")

local u_object = require("app.utils.object")
local u_each = require("app.utils.each")
local u_table = require("app.utils.table")

local s_store = require("app.store.base_store")
local s_adapter = require("app.store.cache_adapter")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_store:extend()

--[[
---> 公开字段
--]]
_obj.support_types = { "nginx", "redis" }

--[[
---> 初始化构造器
--]]
function _obj:new(options)
    self._VERSION = '0.02'
    self._name = s_format("%s-%s-cache", options.store_group, (options and options.name or "anonymity"))
    self._locker_name = ( options and options.locker_name ) or "sys_locker"

    self._store_group = options.store_group
    self._store_config = options.conf
    self._cache = s_adapter:new(self._store_config)[self._store_group]()
    self._cache_name = self._cache._name

    _obj.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------
--[[
---> 将OK值转换为err信息
--]]
function _obj:parse_callback( ... )
    local args = { ... }

    local filter_value = function ( value )
        if type(value) == "table" then
            return value:get_data()
        end

        return value
    end

    -- 常规模式 records, err 为正常搭配，而orm则为 ok, records（该模式当ok为非true时，会变成描述详细错误）
    local ok, records, err, timeout
    if type(args[1]) ~= 'boolean' and type(args[1] ~= 'string') then
        records = args[1]
        err = args[2]
    else
        ok = args[1]
        if ok == true then
            local orm_records = args[2]
            if u_object.check(orm_records) then
                if u_table.is_array(orm_records) then
                    records = {}
                    u_each.array_action(orm_records, function(idx, record)
                        records[idx] = filter_value(record)
                    end)
                else
                    records = filter_value(orm_records)
                end
            end
            timeout = args[3]
        else
            -- orm 模式在报错时，ok值会变成错误信息
            err = ok
        end
    end

    return records, err, timeout
end

-- 从缓存获取不存在时更新并返回
function _obj:get_or_load(key, callback, timeout)
    local value, err = self:get(key)
    if not u_object.check(value) then -- cache missing
        -- 定义锁对象
        local lock = r_lock:new(self._locker_name)
        
        -- 定义解锁函数
        local unlock = function(_lock)
            -- 正常解锁
            local ok, err = _lock:unlock()
            if not ok then
                n_log(n_err, "METHOD:[get_or_load.unlock] KEY:["..key.."], failed to unlock，Final: "..err)
            end
        end

        -- 开始进入锁，访问将在此处阻塞，如果锁以被占用则当前请求被阻塞  
        local elapsed, err = lock:lock(key) 
        if not elapsed then
            --锁超时,被自动释放,根据自己的业务情况选择后续动作  
            n_log(n_err, "METHOD:[get_or_load.lock] KEY:["..key.."], failed to acquire the lock: "..err)
            return
        end

        value, err = self:get(key)  -- 2：锁定期间再次从REDIS中获取信息
        if not u_object.check(value) then       
            value, err, tot = self:parse_callback(callback(key)) -- self.db:query(db_opts.query_text, db_opts.query_params)  -- 读取DB信息

            -- 内部传输的设置过期时间，因timeout为值类型，不能直接变更
            if tot then
                timeout = tot
            end

            -- 无记录报错
            if err then
                n_log(n_err, "METHOD:[get_or_load] KEY:["..key.."], callback get data error: "..err)
                unlock(lock)
                return value, err
            end
            
            local _type = type(value)
            if(_type == "table" or _type == "userdata") then 
                value = c_json.encode(value)
            end

            if value then
                -- 设置读取值进入缓存
                local ok,err = self:set(key, value, timeout)
                if not ok then
                    n_log(n_err, "METHOD:[get_or_load] KEY:["..key.."], update local error: "..err)
                else
                    n_log(n_debug, s_format("METHOD:[get_or_load] KEY:[%s] successed!", key))
                end
            else
                n_log(n_debug, s_format("METHOD:[get_or_load] KEY:[%s], records not found!", key))
            end
        end
        
        unlock(lock)
    end

    return c_json.decode(value) or value, err
end

-- 保存到存储系统并更新本地缓存
function _obj:save_and_update(key, value, callback, timeout)
    local ok, err = callback(key, value) -- true or false
    if ok then
        local json_value = u_object.to_json(value)
        ok, err = self:set(key, json_value, timeout)
        if err or not ok then
            n_log(n_err, "METHOD:[save_and_update] KEY:["..key.."], cache update error: "..err)
            return false
        end

        return true
    else
        n_log(n_err, "METHOD:[save_and_update] KEY:["..key.."], callback save error"..err)
        return false
    end
end

-- 更新本地缓存并保存到存储系统
function _obj:update_and_save(key, value, callback, timeout)
    -- value, err, tot = self:parse_callback(callback(key))
    local json_value = u_object.to_json(value)
    local ok, err = self:set(key, json_value, timeout)
    if err or not ok then
        n_log(n_err, "METHOD:[update_and_save] KEY:["..key.."], cache update error: "..err)
        return false
    end
    
    ok, err = callback(key, value) -- true or false
    if not ok then
        n_log(n_err, "METHOD:[update_and_save] KEY:["..key.."], callback save error"..err)
        return false
    end

    return true
end

-- 从存储获取并更新缓存
function _obj:load_and_set(key, callback, timeout)
    local err, value = callback(key)

    if err or not value then
        n_log(n_err, "METHOD:[load_and_set] KEY:["..key.."], callback load error: "..err)
        return false
    else
        local ok, errr = self:set(key, value, timeout)
        if errr or not ok then
            n_log(n_err, "METHOD:[load_and_set] KEY:["..key.."], cache set error: ", errr)
            return false
        end

        return true
    end
end

function _obj:get(key)
    return self._cache:get(key)
end

function _obj:get_json(key)
    local value, f = self:get(key)
    if value then
        value = c_json.decode(value)
    end
    return value, f
end

function _obj:set(key, value, timeout)
    return self._cache:set(key, value, timeout)
end

function _obj:set_json(key, value, timeout)
    if value then
        value = c_json.encode(value)
    end
    return self:set(key, value, timeout)
end

function _obj:incr(key, value, timeout)
    return self._cache:incr(key, value, timeout)
end

-----------------------------------------------------------------------------------------------------------------

function _obj:lpush(key, value)
    return self._cache:lpush(key, value)
end

function _obj:llen(key)
    return self._cache:llen(key)
end

function _obj:rpush(key, value)
    return self._cache:rpush(key, value)
end

function _obj:lpop(key, value)
    return self._cache:lpop(key, value)
end

function _obj:rpop(key, value)
    return self._cache:rpop(key, value)
end

-- 并行提交
-- local ok, err = self.store.cache.intranet_redis:pipeline_command(function (redis)
-- end)

-- if err then
--     n_log(n_err, s_format("METHOD:[service.%s.push.pipeline] QUEUE:[%s] failure! error: %s", self._name, queue_name, err))
-- end
function _obj:pipeline_command(action)
    return self._cache:pipeline_command(action)
end

-----------------------------------------------------------------------------------------------------------------

function _obj:hmset(key, value, timeout)
    return self._cache:hmset(key, value, timeout)
end

function _obj:keys(pattern)
    return self._cache:keys(pattern)
end

-----------------------------------------------------------------------------------------------------------------

function _obj:append(key, item, limit)
    return self._cache:append(key, item, limit)
end

-----------------------------------------------------------------------------------------------------------------

function _obj:del(key)
    return self._cache:delete(key)
end

function _obj:delete(key)
    return self._cache:delete(key)
end

function _obj:delete_all()
    return self._cache:delete_all()
end

-----------------------------------------------------------------------------------------------------------------

return _obj