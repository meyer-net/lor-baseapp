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
        local plugins_conf = self._conf.plugins_conf
        if not plugins_conf then
            self._log.err("[%s-%s] Can't find node of plugins_conf from sys.conf, nginx exit.", self._name, rule.name)
            ngx.exit(-1)
        end

        local plugins_conf_alias = plugins_conf.alias
        if not plugins_conf_alias then
            self._log.err("[%s-%s] Can't find node of plugins_conf.alias from sys.conf, nginx exit.", self._name, rule.name)
            ngx.exit(-1)
        end

        local alias_server_port = plugins_conf_alias.port
        local localhost = "127.0.0.1"
        ngx_var.upstream_host = localhost
        ngx_var.upstream_url = self.format("http://%s:%s", localhost, alias_server_port)
        ngx.req.set_header("alias", handle.alias)

        local ext = u_request:get_ext_by_uri(ngx_var.request_uri)
        if self.utils.object.check(ext) then
            ngx.header.content_type = u_request:get_content_type_by_ext(ext)
        end
        
        self:rule_log_info(rule, self.format("[%s-%s] Alias to: '%s' success. host: %s, uri: %s", self._name, rule.name, handle.alias, ngx_var_host, ngx_var_uri))
    end
end

-----------------------------------------------------------------------------------------------------------------

function handler:rewrite()
    self:exec_action(self._rewrite_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler