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

local s_gsub = string.gsub

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

--------------------------------------------------------------------------

handler.utils.args = require("app.utils.args")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 handler.super.new(self, name)
--]]
function handler:new(conf, store)
    -- 优先级调控
    self.PRIORITY = 9998

    -- 插件名称
    self._source = "capture"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:_rewrite_action(rule, variables, conditions_matched)
    local ngx_var = ngx.var
    local ngx_var_host = ngx_var.host
    local ngx_var_uri = ngx_var.uri

    local n_req = ngx.req
    local micro_handle = self:combine_micro_handle_by_rule(rule)
    local capture_uri = self.format("/capture_proxy/%s", s_gsub(s_gsub(micro_handle.url, "://","/"), ":", "/"))
    local method = n_req.get_method()
    if (method ~= "GET") then
        n_req.read_body()
    end

    local capture_method = ngx[self.format("HTTP_%s", method)]
    local res, err = ngx.location.capture(capture_uri, {
        method = capture_method,
        copy_all_vars = true,
        vars = { 
            capture_host = micro_handle.host,
            capture_payload = ngx.ctx.payload
        }
    })
    
    if res.status == ngx.HTTP_OK then
        self:rule_log_info(rule, self.format("[%s-%s] Get response from '%s', status: %s. host: %s, uri: %s", self._name, rule.name, micro_handle.url, res.status, ngx_var_host, ngx_var_uri))
    else
        self:rule_log_err(rule, self.format("[%s-%s] Get response from '%s' error, status: %s, error: %s. host: %s, uri: %s", self._name, rule.name, micro_handle.url, res.status, err, ngx_var_host, ngx_var_uri))
    end

    if rule.handle.content_type then
        ngx.header['Content-Type'] = rule.handle.content_type
    end
    
    ngx.status = res.status
    ngx.say(res.body)
end

-----------------------------------------------------------------------------------------------------------------

function handler:rewrite()
    self:exec_action(self._rewrite_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler