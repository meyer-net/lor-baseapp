-- 
--[[
---> 用于将当前插件提供为具体系统的上下文
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
--------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local p_base = require("app.plugins.handler_adapter")

--------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local handler = p_base:extend()

-----------------------------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 handler.super.new(self, name)
--]]
function handler:new(conf, store)
    -- 插件名称
    self._source = "default"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:redirect()
    -- self._log.err("load exec redirect")
end

function handler:rewrite()
    -- self._log.err("load exec rewrite")
end

function handler:access()
    -- self._log.err("load exec access")
    local rule_pass_func = function (rule, variables, rule_matched)     
        local ngx_var = ngx.var
        local ngx_var_host = ngx_var.host
        local ngx_var_uri = ngx_var.uri

        self:rule_log_err(rule, self.format("[%s-%s] notset_message. host: %s, uri: %s", self._name, rule.name, ngx_var_host, ngx_var_uri))
    end

    return self:exec_action(rule_pass_func)
end

function handler:header_filter()
    -- self._log.err("load exec header_filter")
end

function handler:body_filter()
    -- self._log.err("load exec header_filter")
end

function handler:log()
    -- self._log.err("load exec log")
end

-----------------------------------------------------------------------------------------------------------------

return handler