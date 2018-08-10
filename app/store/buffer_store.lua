-- 自定义函数指针
local type = type

local s_format = string.format

-- 统一引用导入LIBS
local s_store = require("app.store.base_store")
local s_adapter = require("app.store.buffer_adapter")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_store:extend()

--[[
---> 公开字段
--]]
_obj.support_types = { "nginx", "redis", "kafka" }

--[[
---> 初始化构造器
--]]
function _obj:new(options)
    self._VERSION = '0.01'
    self._name = ( options and options.name or "anonymity" ) .. " buffer store"
    self._locker_name = ( options and options.locker_name ) or "sys_locker"

    self.store_group = options.store_group
    self.store_config = options.conf
    self.buffer = s_adapter:new(self.store_config)[self.store_group]()

    _obj.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------

-- 推送 REDIS 缓存值
function _obj:lpush(key, value, partition)
    return self.buffer:lpush(key, value, partition)
end

-- 推送 REDIS 缓存值
function _obj:rpush(key, value, partition)
    return self.buffer:rpush(key, value, partition)
end

-----------------------------------------------------------------------------------------------------------------

return _obj