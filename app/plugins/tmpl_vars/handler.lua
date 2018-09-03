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
local r_template = require("resty.template")

-----> 业务引用
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
    self.PRIORITY = 0

    -- 插件名称
    self._source = "tmpl_vars"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:_body_filter_action(rule, variables, conditions_matched)
    self:exec_filter(function (body)
        local ngx_var = ngx.var
        local ngx_var_host = ngx_var.host
        local ngx_var_uri = ngx_var.uri

        local handle = rule.handle
        if handle and handle.tmpl_vars then
            local n_req = ngx.req

            local method = n_req.get_method()
            local sub_method = ngx[self.format("HTTP_%s", method)]
            
            -- 插入新的變量<!--# echo var="http_user_agent" default=""-->
            
            local context = {}
            self.utils.each.array_action(handle.tmpl_vars, function ( _, pair )
                context[pair.key] = pair.value
            end)
            
            ngx.arg[1] = r_template.compile(body)(context)
            
            self:rule_log_info(rule, self.format("[%s-%s] Get ssi response. host: %s, uri: %s", self._name, rule.name, ngx_var_host, ngx_var_uri))
        else
            ngx.arg[1] = body
            
            self:rule_log_info(rule, self.format("[%s-%s] No template vars, get source response. host: %s, uri: %s", self._name, rule.name, ngx_var_host, ngx_var_uri))
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------

function handler:body_filter(body)
    self:exec_action(self._body_filter_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler