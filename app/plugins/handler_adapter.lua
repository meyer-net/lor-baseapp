--
--[[
---> 用于操作来自于鉴权的系列流程，并将请求下发至下游系统。
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
-- 数据库配置数据
-- 特别注释
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require

local s_format = string.format
local s_find = string.find
local s_sub = string.sub
local s_gsub = string.gsub

local n_var = ngx.var
local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local r_cookie = require("resty.cookie")
local base_handler = require("app.plugins.base_handler")

-----> 工具引用
-- local u_object = require("app.utils.object")
-- local u_table = require("app.utils.table")
-- local u_each = require("app.utils.each")
-- local u_args = require("app.utils.args")
-- local u_json = require("app.utils.json")
-- local u_string = require("app.utils.string")
-- local u_handle = require("app.utils.handle")
local u_request = require("app.utils.request")
-- local u_jwt = require("app.utils.jwt")
-- local ue_error = require("app.utils.exception.error")

-----> 外部引用
local c_json = require("cjson.safe")

-----> 必须引用
--

-----> 业务引用
--

-----> 数据仓储引用
local s_log = require("app.model.service.sys.log_svr")

--------------------------------------------------------------------------

--[[
---> 实例信息及配置
--]]
local handler = base_handler:extend()

function handler:new(conf, store, name)
    -- self.PRIORITY = 9999

    -- 构造一个新的日志器对象
    -- local log = s_log(conf, store, s_format("plugins.%s", self._source or "anonymity"))
    -- local opts = {
    --     log = {
    --         log = function ( level, fmt, ... )
    --             return log:write_log(level, fmt, ...)
    --         end,
    --         err = function(fmt, ...)
    --             return log:write_log(n_err, fmt, ...)
    --         end,

    --         info = function(fmt, ...)
    --             return log:write_log(n_info, fmt, ...)
    --         end,

    --         debug = function(fmt, ...)
    --             return log:write_log(n_debug, fmt, ...)
    --         end
    --     }
    -- }
    
	-- 传导至父类填充基类操作对象
    handler.super.new(self, conf, store, self._source, opts)

    self._request = u_request(self._name)
end

--------------------------------------------------------------------------

function handler:redirect()
    -- n_log(n_err, "load exec redirect")
end

function handler:rewrite()
    -- n_log(n_err, "load exec rewrite")
end

function handler:access()
    -- n_log(n_err, "load exec access")
end

function handler:header_filter()
    -- n_log(n_err, "load exec header_filter")
end

function handler:body_filter()
    -- n_log(n_err, "load exec header_filter")
end

function handler:log()
    -- n_log(n_err, "load exec log")
end

--------------------------------------------------------------------------
return handler