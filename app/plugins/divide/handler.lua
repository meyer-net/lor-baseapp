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
    -- 优先级调控
    self.PRIORITY = 2

    -- 插件名称
    self._source = "divide"

	-- 传导至父类填充基类操作对象
    handler.super.new(self, conf, store)
end

-----------------------------------------------------------------------------------------------------------------

function handler:_rewrite_action(rule, variables, conditions_matched)
    local ngx_var = ngx.var
    local ngx_var_uri = ngx_var.uri
    local ngx_var_host = ngx_var.host

    local micro_handle = self:combine_micro_handle_by_rule(rule, variables) 
    local upstream_url = micro_handle.url
    if upstream_url then
        if self.utils.object.check(micro_handle.host) then
            ngx_var.upstream_host = micro_handle.host
        end

        ngx_var.upstream_url = micro_handle.url
    else
        self:rule_log_err(rule, self.format("[%s-%s] no upstream host or url. host: %s, uri: %s", self._name, rule.name, ngx_var_host, ngx_var_uri))
    end
end

-----------------------------------------------------------------------------------------------------------------

function handler:rewrite()
    self:exec_action(self._rewrite_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler