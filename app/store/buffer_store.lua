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
    self._name = ( options and options.name or "anonymity") .. " buffer store"
    self._locker_name = ( options and options.locker_name ) or "sys_locker"

    self.store_group = options.store_group
    self.store_config = options.conf
    self.buffer = s_adapter:new(self.store_config)[self.store_group]()
    
    self._db_mode = options.db_mode

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