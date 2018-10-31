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

local s_sub = string.sub
local s_gsub = string.gsub

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local p_base = require("app.plugins.handler_adapter")

-----> 工具库引用
local u_request = require("app.utils.request")

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
    self.PRIORITY = 9997

    -- 插件名称
    self._source = "alias"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:_rewrite_action(rule, variables, conditions_matched)
    local ngx_var = ngx.var
    local ngx_var_host = ngx_var.host
    local ngx_var_uri = ngx_var.uri

    local handle = rule.handle
    if handle and handle.alias then
        local replaced = false
        local alias_uri = ngx_var.request_uri
        self.utils.each.array_action(conditions_matched, function ( _, condition )
            local sub_str = condition.matched
            if condition.matched ~= "/" and not self.utils.string.ends_with("/") then
                sub_str = self.format("%s/", sub_str)
            end
            if condition.type == "URI" then
                local local_uri = s_gsub(alias_uri, sub_str, "/")

                -- 调整请求路径
                alias_uri = self.format("/alias/%s", local_uri)

                replaced = true
            end
        end)
        
        if not replaced then
            alias_uri = self.format("/alias%s", ngx_var.request_uri)
        end

        local ext = u_request:get_ext_by_uri(alias_uri)
        if not self.utils.object.check(ext) then
            alias_uri = self.format("%s/index.html", alias_uri)
        end

        local n_req = ngx.req
        local method = n_req.get_method()
        if (method ~= "GET") then
            n_req.read_body()
        end
        
        ngx.header.content_type = u_request:get_content_type_by_ext(ext)
        local capture_method = ngx[self.format("HTTP_%s", method)]
        local res, err = ngx.location.capture(alias_uri, {
            method = capture_method,
            copy_all_vars = true,
            vars = { 
                alias = handle.alias
            }
        })
    
        if res.status == ngx.HTTP_OK or res.status == ngx.HTTP_CREATED or res.status == ngx.HTTP_ACCEPTED then
            self:rule_log_info(rule, self.format("[%s-%s] Alias to: '%s' success, status: %s. host: %s, uri: %s", self._name, rule.name, handle.alias, res.status, ngx_var_host, ngx_var_uri))
        else
            self:rule_log_err(rule, self.format("[%s-%s] Alias to: '%s' error, status: %s, error: %s. host: %s, uri: %s", self._name, rule.name, handle.alias, res.status, err, ngx_var_host, ngx_var_uri))
        end
        
        ngx.status = res.status
        ngx.say(res.body)
        ngx.exit(res.status)
    end
end

-----------------------------------------------------------------------------------------------------------------

function handler:rewrite()
    self:exec_action(self._rewrite_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler