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

local n_stderr = ngx.STDERR
local n_emerg = ngx.EMERG
local n_alert = ngx.ALERT
local n_crit = ngx.CRIT
local n_err = ngx.ERR
local n_warn = ngx.WARN
local n_notice = ngx.NOTICE
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local l_object = require("app.lib.classic")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _obj = l_object:extend()

-----------------------------------------------------------------------------------------------------------------

-----> 工具系列
_obj.utils = {
    ex = {}
}
_obj.utils.json = require("cjson.safe")
_obj.utils.object = require("app.utils.object")
_obj.utils.table = require("app.utils.table")
_obj.utils.each = require("app.utils.each")
_obj.utils.string = require("app.utils.string")
_obj.utils.ex.error = require("app.utils.exception.error")

-----> 日志系列
_obj.format = string.format
_obj.sub = string.sub
_obj.read_format = function (fmt, ...)
    local format = fmt
    if ... ~= nil then
        format = _obj.format(fmt, ...)
    end

    return format
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 _obj.super.new(self, name)
--]]
function _obj:new(name, opts)
    self._name = name or "anonymity-classic"

	-- 传导至父类填充基类操作对象
    _obj.super.new(self, name)
    
    -- 选项设定
    self._slog = {
        log = function ( level, fmt, ... )
                return n_log(level, _obj.read_format(fmt, ...))
            end,
        stderr  = function (fmt, ...)
                return n_log(n_stderr, _obj.read_format(fmt, ...))
            end,
        emerg  = function (fmt, ...)
                return n_log(n_emerg, _obj.read_format(fmt, ...))
            end,
        alert  = function (fmt, ...)
                return n_log(n_alert, _obj.read_format(fmt, ...))
            end,
        crit  = function (fmt, ...)
                return n_log(n_crit, _obj.read_format(fmt, ...))
            end,
        err  = function (fmt, ...)
                return n_log(n_err, _obj.read_format(fmt, ...))
            end,
        warn  = function (fmt, ...)
                return n_log(n_warn, _obj.read_format(fmt, ...))
            end,
        notice  = function (fmt, ...)
                return n_log(n_notice, _obj.read_format(fmt, ...))
            end,
        info  = function (fmt, ...)
                return n_log(n_info, _obj.read_format(fmt, ...))
            end,
        debug  = function (fmt, ...)
                return n_log(n_debug, _obj.read_format(fmt, ...))
            end
    }

    self._log = (opts and opts.log) or self._slog
end

-----------------------------------------------------------------------------------------------------------------

return _obj