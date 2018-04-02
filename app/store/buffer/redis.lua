-- 自定义函数指针
local type = type

local c_json = require("cjson.safe")
local u_each = require("app.utils.each")
local s_buffer = require("app.store.buffer.base_buffer")
local r_cache = require("app.store.redis")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_buffer:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -------------------------------------

--[[
---> RDS 选区
--]]
function _obj:new(conf)
    self._VERSION = '0.01'
    self._name = "buffer-redis-store"

    _obj.super.new(self, conf)
end

----------------------------------------------- REDIS 缓存设置 --------------------------------------------------

--[[
---> RDS 连接器
--]]
function _obj:_get_connect( timeout )
	local config = self.conf
	if timeout then
		config.timeout = timeout
	end

	return r_cache:new(config)
end

-----------------------------------------------------------------------------------------------------------------

-- 推送 REDIS 缓存值
function _obj:lpush(key, value, partition, timeout)
	source_key = key
	key=self:topickey_format(key, partition)

	-- 获取缓存连接器
	local redis = self:_get_connect()

	self:record_mq_keys(redis, source_key, key)
	local offset,err = redis:lpush(key, value)
	timeout = self:filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return offset > 0, err, offset
end

-- 推送 REDIS 缓存值
function _obj:rpush(key, value, partition, timeout)
	source_key = key
	key=self:topickey_format(key, partition)

	-- 获取缓存连接器
	local redis = self:_get_connect()

	self:record_mq_keys(redis, source_key, key)
	local offset,err = redis:rpush(key, value)
	timeout = self:filter_timeout(timeout, function ()
		-- 设置当前KEY的过期时间，-s 秒为
		redis:expire(key, timeout)
	end)

	return offset > 0, err, offset
end

-----------------------------------------------------------------------------------------------------------------

return _obj