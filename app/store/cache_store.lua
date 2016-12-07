-- 自定义函数指针
local type = type
local n_log = ngx.log
local n_err = ngx.ERR

-- 统一引用导入LIBS
local c_json = require("cjson.safe")
local r_lock = require("resty.lock")

local u_object = require("app.utils.object")

local s_store = require("app.store.base_store")
local s_adapter = require("app.store.cache_adapter")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_store:extend()

--[[
---> 初始化构造器
--]]
function _obj:new(options)
    self._VERSION = '0.02'
    self._name = ( options and  options.name or "anonymity") .. " cache store"
    self._locker_name = ( options and options.locker_name ) or "sys_locker"

    self.cache = s_adapter:new(options.config)[options.cache_type]()
    self.store_type = cache_type

    _obj.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------

-- 从缓存获取不存在时更新并返回
function _obj:get_or_load(key, callback, timeout)
    local value, err = _obj:get(key)

    if not u_object.check(value) then -- cache missing
        -- 定义锁对象
        local lock = r_lock:new(self._locker_name)
        
        -- 定义解锁函数
        local unlock = function(_lock)
            -- 正常解锁
            local ok, err = _lock:unlock()
            if not ok then
                n_log(n_err, "METHOD:[get_or_load.unlock] KEY:[", key, "], failed to unlock，Final: ", err)
            end
        end

        -- 开始进入锁，访问将在此处阻塞
        local elapsed, err = lock:lock(key)
        if not elapsed then
            n_log(n_err, "METHOD:[get_or_load.lock] KEY:[", key, "], failed to acquire the lock: ", err)
            return
        end

        value, err = _obj:get(key)  -- 2：锁定期间再次从REDIS中获取信息
        if not u_object.check(value) then       
            value, err, errno, sqlstate = callback(key) -- self.db:query(db_opts.query_text, db_opts.query_params)  -- 读取DB信息
            -- 无记录报错
            if err then
                n_log(n_err, "METHOD:[get_or_load] KEY:[", key, "], callback get date error:", err)
                unlock(lock)
                return value, err
            end
            
            local _type = type(value)
            if(_type == "table" or _type == "userdata") then 
                value = c_json.encode(value)
            end

            -- 设置读取值进入缓存
            local ok,err = _obj:set(key, value, timeout)
            if not ok then
                n_log(n_err, "METHOD:[get_or_load] KEY:[", key, "], update local error:", err)
            else
                ngx.log(ngx.DEBUG, string.format("METHOD:[get_or_load] KEY:[%s] successed!", key))
            end
        end

        unlock(lock)
    end

    return value, err
end

-- 保存到存储系统并更新本地缓存
function _obj:save_and_update(key, value, callback, timeout)
    local result = callback(key, value) -- true or false
    if result then
        local ok, err = _obj:set(key, value, timeout)
        if err or not ok then
            n_log(n_err, "METHOD:[save_and_update] KEY:[", key, "], update error:", err)
            return false
        end

        return true
    else
        n_log(n_err, "METHOD:[save_and_update] KEY:[", key, "], save error")
        return false
    end
end

-- 从存储获取并更新缓存
function _obj:load_and_set(key, callback, timeout)
    local err, value = callback(key)

    if err or not value then
        n_log(n_err, "METHOD:[load_and_set] KEY:[", key, "], load error:", err)
        return false
    else
        local ok, errr = _obj:set(key, value, timeout)
        if errr or not ok then
            n_log(n_err, "METHOD:[load_and_set] KEY:[", key, "], set error:", errr)
            return false
        end

        return true
    end
end

function _obj:get(key)
    return self.cache:get(key)
end

function _obj:get_json(key)
    local value, f = _obj:get(key)
    if value then
        value = c_json.decode(value)
    end
    return value, f
end

function _obj:set(key, value, timeout)
    return self.cache:set(key, value, timeout)
end

function _obj:set_json(key, value, timeout)
    if value then
        value = c_json.encode(value)
    end
    return _obj:set(key, value, timeout)
end

function _obj:incr(key, value, timeout)
    return self.cache:incr(key, value, timeout)
end

function _obj:delete(key)
    self.cache:delete(key)
end

function _obj:delete_all()
    self.cache:delete_all()
end

-----------------------------------------------------------------------------------------------------------------

function _obj:lpush(key, value)
    return self.cache:lpush(key, value)
end

function _obj:llen(key)
    return self.cache:llen(key)
end

function _obj:rpush(key, value)
    return self.cache:rpush(key, value)
end

function _obj:lpop(key, value)
    return self.cache:lpop(key, value)
end

function _obj:rpop(key, value)
    return self.cache:rpop(key, value)
end

-- 并行提交
-- local ok, err = self.store.cache.intranet_redis:pipeline_command(function (redis)
-- end)

-- if err then
--     n_log(n_err, s_format("METHOD:[service.%s.push.pipeline] QUEUE:[%s] failure! error: %s", self._name, queue_name, err))
-- end
function _obj:pipeline_command(action)
    return self.cache:pipeline_command(action)
end

-----------------------------------------------------------------------------------------------------------------

function _obj:hmset(key, value, timeout)
    return self.cache:hmset(key, value, timeout)
end

function _obj:keys(pattern)
    return self.cache:keys(pattern)
end

-----------------------------------------------------------------------------------------------------------------

return _obj