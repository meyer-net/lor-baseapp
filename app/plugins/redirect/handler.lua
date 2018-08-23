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
local ipairs = ipairs
local tonumber = tonumber

local s_find = string.find

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
    self.PRIORITY = 9999

    -- 插件名称
    self._source = "redirect"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:_redirect_action(rule, variables, conditions_matched)
    local ngx_var = ngx.var
    local ngx_var_uri = ngx_var.uri
    local ngx_var_args = ngx_var.args
    local ngx_var_host = ngx_var.host
    local ngx_redirect = ngx.redirect

    local handle = rule.handle
    if handle and handle.url_tmpl then
        local redirect_url = self.utils.handle.build_url(rule.extractor.type, handle.url_tmpl, variables)
        if redirect_url ~= ngx_var_uri then
            local redirect_status = tonumber(handle.redirect_status)
            if redirect_status ~= 301 and redirect_status ~= 302 then
                redirect_status = 301
            end

            if s_find(redirect_url, 'http') ~= 1 then
                redirect_url = self.format("%s://%s%s", ngx_var_scheme, ngx_var_host, redirect_url)
            end

            if ngx_var_args ~= nil then
                if s_find(redirect_url, '?') then -- 不存在?，直接缀上url args
                    if handle.trim_qs ~= true then
                        redirect_url = redirect_url .. "&" .. ngx_var_args
                    end
                else
                    if handle.trim_qs ~= true then
                        redirect_url = redirect_url .. "?" .. ngx_var_args
                    end
                end
            end

            self:rule_log_err(rule, self.format("[%s] match uri '%s' redirect to: '%s'", self._name, ngx_var_uri, redirect_url))

            ngx_redirect(redirect_url, redirect_status)
        end
    end
end

-----------------------------------------------------------------------------------------------------------------

function handler:redirect()
    self:exec_action(self._redirect_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler