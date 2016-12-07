-- 自定义函数指针
local type = type

local s_find = string.find

local c_json = require("cjson.safe")
local r_cache = require("app.store.redis")
local u_each = require("app.utils.each")
local s_cache = require("app.store.cache.base_cache")

-----------------------------------------------------------------------------------------------------------------

local _M = s_cache:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -----------------------------------  

--[[
---> RDS 选区
--]]
function _M:new(conf)
    self._VERSION = '0.02'
    self._name = "cache-redis-store"

    self.config = conf

    _M.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------

----------------------------------------------- REDIS 缓存设置 --------------------------------------------------

--[[
---> RDS 连接器
--]]
function _M:_get_connect( timeout )
	local config = self.config
	if timeout then
		config.timeout = timeout
	end

	return r_cache:new(config)
end

-- 设置 REDIS 缓存值
function _M:set_by_json(json, timeout)
	local json_obj = c_json.decode(json)

	-- 获取缓存连接器
	local redis = self:_get_connect()

	local effect_len = 0

	redis:init_pipeline()

	u_each.json_action(json_obj, function(key,value)
		-- 设置缓存
		redis:set(key, value)

		timeout = _M.filter_timeout(timeout, function ()
			-- 设置当前KEY的过期时间，-s 秒为
			redis:expire(key, timeout)
		end)

		if not err then
			effect_len = effect_len + 1
		end
	end)

	local ok,err = redis:commit_pipeline()

	return ok,err,effect_len
end

-- 设置 REDIS 缓存值
function _M:set(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:set(key, value)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 设置 REDIS 缓存值
function _M:hmset_by_array_text(key, array_text, timeout)
	local value = c_json.decode(array_text)
	return self:hmset(key, value, timeout)
end

-- 设置 REDIS 缓存值
function _M:hmset(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:hmset(key, unpack(value))
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)


	return ok,err,#(value) / 2
end

-- 设置 REDIS 缓存值 依据 function
function _M:set_by_func(key, func, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:set(key, func())
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 获取 REDIS 缓存值
function _M:get(key)
	-- 获取缓存连接器
	local redis = self:_get_connect()
	local status,value,effect_len = "OK",nil,0
	local value,err = redis:get(key)
	if not value then
		status = "FAILURE"
	else
		effect_len = 1
	end

	return value,err,effect_len,status
end

-- 获取 REDIS 缓存值
function _M:hmget(key, element_key)
	-- 获取缓存连接器
	local redis = self:_get_connect()
	local status,value,effect_len = "OK",nil,0
	local value,err = redis:hmget(key, element_key)

	if not value then
		status = "FAILURE"
	else
		effect_len = 1
	end

	return value,err,effect_len,status
end

-- 获取 REDIS 缓存值
function _M:hmget_array_text(key, element_key)
	local value,err,effect_len,status = _M:hmget(key, element_key)
	return c_json.encode(value),err,effect_len,status
end

function _M:delete(key)
	-- 获取缓存连接器
	local redis = self:_get_connect()

    redis:delete(key)
end

function _M:delete_all()
	-- 获取缓存连接器
	local redis = self:_get_connect()

    redis:flush_all()
    redis:flush_expired()
end

-----------------------------------------------------------------------------------------------------------------

-- 推送 REDIS 缓存值
function _M:lpush(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:lpush(key, value)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 推送 REDIS 缓存值
function _M:llen(key)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	return redis:llen(key)
end

-- 推送 REDIS 缓存值
function _M:rpush(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:rpush(key, value)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 推送 REDIS 缓存值
function _M:lpop(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:lpop(key, value)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 推送 REDIS 缓存值
function _M:rpop(key, value, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:rpop(key, value)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return ok,err
end

-- 设置 REDIS 缓存值
function _M:incr(key, step, timeout)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	local ok,err = redis:incr(key)
	timeout = _M.filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, step, timeout)
	end)

	return ok,err
end

-- 同一连接，执行命令
function _M:pipeline_command(action)
	-- 获取缓存连接器
	local redis = self:_get_connect()

	redis:init_pipeline()

	action(redis)

	return redis:commit_pipeline()
end

function _M:keys(pattern)
	-- 获取缓存连接器
	local redis = self:_get_connect()
	
    return redis:keys(pattern)
end

-----------------------------------------------------------------------------------------------------------------

return _M