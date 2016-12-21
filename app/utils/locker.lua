-- 
--[[
---> 
--------------------------------------------------------------------------
---> 参考文献如下
-----> 
--------------------------------------------------------------------------
---> Examples：
-----> 
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require
local type = type

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

local s_format = string.format
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local r_lock = require("resty.lock")
local object = require("app.lib.classic")

-----> 工具引用
local u_object = require("app.utils.object")
local u_each = require("app.utils.each")

-----> 外部引用
local c_json = require("cjson.safe")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _obj = object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 _obj.super.new(self, store, self._name)
--]]
function _obj:new(shard_dict, name)
	-- 用于锁处理的对象
	self.store = shard_dict

	-- 指定名称
    self._name = (name or "anonymity") .. "-lock"
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 设置指定锁的解锁时间
--]]
function _obj:set_action_release_time(locker_name)
    local key = self._name.."-"..locker_name.."-lock-release-time"
    self.store:set(key, ngx.now())
end

--[[
---> 指定锁的解锁时间
--]]
function _obj:get_action_release_time(locker_name)
    local key = self._name.."-"..locker_name.."-lock-release-time"

    -- 保证操作永远在前
    return self.store:get(key)
end

--[[
---> 执行锁定任务
---> 阻塞时后续命令会跳出等，可转向为对KEY的缓存时间控制
--]]
function _obj:jump_action(locker_name, execute_func, opts)
    local key_name = self._name

    -- 定义锁对象
    local lock = r_lock:new(locker_name, opts)
    
    -- 定义解锁函数
    local unlock = function(_lock)
        -- 正常解锁
        local ok, err = _lock:unlock()
        if not ok then
            n_log(n_err, "METHOD:[locker.jump_action.unlock] KEY:[", key_name, "], failed to unlock，Final: ", err)
        else
            self:set_action_release_time(locker_name)
        end
    end
    
    -- 开始进入锁，访问将在此处阻塞，后续的请求，全部在此驳回
    local elapsed, err = lock:lock(key_name)
    if err == "timeout" then
        return err, nil
    end

    if not elapsed then
        n_log(n_err, "METHOD:[locker.jump_action.lock] KEY:[", key_name, "], failed to acquire the lock: ", err)
        return
    else
        value, err = execute_func(key_name) -- 执行用户请求
    end
    -- 无记录报错
    if err then
        n_log(n_err, "METHOD:[locker.jump_action] KEY:[", key_name, "], exec lock.func error: ", err)
        unlock(lock)
        return value, err
    end
            
    local _type = type(value)
    if(_type == "table" or _type == "userdata") then 
        value = c_json.encode(value)
    end

    unlock(lock)

    return value, err
end

--[[
---> 执行锁定任务
---> 外部的多久执行一次，阻塞时后续命令会跳出等，可转向为对KEY的缓存时间控制
--]]
function _obj:action(locker_name, execute_func, timeout)
	local key_name = self._name
    local value, err = self.store:get(key_name)
    if err then
        n_log(n_err, "METHOD:[locker.action] KEY:[", key_name, "], init get error: ", err)
        return value, err
    end

    if not u_object.check(value) then -- cache missing
    	-- 定义锁对象
    	local lock = r_lock:new(locker_name)
    	
    	-- 定义解锁函数
    	local unlock = function(_lock)
    	    -- 正常解锁
    	    local ok, err = _lock:unlock()
    	    if not ok then
    	        n_log(n_err, "METHOD:[locker.action.unlock] KEY:[", key_name, "], failed to unlock，Final: ", err)
            else
                self:set_action_release_time(locker_name)
    	    end
    	end
	
    	-- 开始进入锁，访问将在此处阻塞
    	local elapsed, err = lock:lock(key_name)
    	if not elapsed then
    	    n_log(n_err, "METHOD:[locker.action.lock] KEY:[", key_name, "], failed to acquire the lock: ", err)
    	    return
    	end
	
    	-- 接受阻塞后，后续释放的请求，全部在此驳回
    	value, err = self.store:get(key_name)
    	if not u_object.check(value) then    
			value, err = execute_func(key_name) -- 执行用户请求
    		-- 无记录报错
    		if err then
    		    n_log(n_err, "METHOD:[locker.action] KEY:[", key_name, "], exec lock.func error: ", err)
    		    unlock(lock)
    		    return value, err
    		end
		            
            local _type = type(value)
            if(_type == "table" or _type == "userdata") then 
                value = c_json.encode(value)
            end

            -- 设置读取值进入缓存
            local ok,err = self.store:set(key_name, value, timeout)
            if not ok then
                n_log(n_err, "METHOD:[locker.action] KEY:[", key_name, "], update local error: ", err)
            else
                ngx.log(ngx.DEBUG, s_format("METHOD:[locker.action] KEY:[%s] successed!", key))
            end
		end

    	unlock(lock)
    end

    return value, err
end

-----------------------------------------------------------------------------------------------------------------

return _obj