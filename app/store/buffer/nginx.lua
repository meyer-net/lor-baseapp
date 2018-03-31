-- 自定义函数指针
local type = type

local s_buffer = require("app.store.buffer.base_buffer")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_buffer:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -------------------------------------

--[[
---> NGX 选区
--]]
function _obj:new(conf)
    self._VERSION = '0.01'
    self._name = "buffer-nginx-store"
    self.store = ngx.shared[conf.name]

    _obj.super.new(self, conf)
end

-----------------------------------------------------------------------------------------------------------------

-- 推送 NGINX 缓存值
function _obj:lpush(key, value, partition)
	source_key = key
	key=_obj:topickey_format(key, partition)
    self:record_mq_keys(self.store, source_key, key)
    
    return self.store:lpush(key, value)
end

-- 推送 NGINX 缓存值
function _obj:rpush(key, value, partition)
	source_key = key
    key=_obj:topickey_format(key, partition)
    self:record_mq_keys(self.store, source_key, key)
    
    return self.store:rpush(key, value)
end

-----------------------------------------------------------------------------------------------------------------

return _obj