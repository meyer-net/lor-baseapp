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
    self.PRIORITY = 9997

    -- 插件名称
    self._source = "rewrite"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
	
end

-----------------------------------------------------------------------------------------------------------------

function handler:redirect()
    -- self._log.err("load exec redirect")
end

function handler:rewrite()
    local rule_pass_func = function (rule, variables, rule_matched)
        local ngx_var = ngx.var
        local ngx_var_uri = ngx_var.uri
        local ngx_set_uri = ngx.req.set_uri
        local ngx_set_uri_args = ngx.req.set_uri_args
        local ngx_decode_args = ngx.decode_args
        local ngx_re_find = ngx.re.find

        local handle = rule.handle
        if handle and handle.uri_tmpl then
            local rewrite_uri = self.utils.handle.build_uri(rule.extractor.type, handle.uri_tmpl, variables)
            if rewrite_uri and rewrite_uri ~= ngx_var_uri then
                self:rule_log_err(rule, self.format("[%s] match uri '%s' rewrite to: '%s'", self._name, ngx_var_uri, rewrite_uri))

                local from, to, err = ngx_re_find(rewrite_uri, "[%?]{1}", "jo")
                if not err and from and from >= 1 then
                    local query_string = s_sub(rewrite_uri, from + 1)
                    if query_string then
                        local args = ngx_decode_args(query_string, 0)
                        if args then 
                            ngx_set_uri_args(args) 
                        end
                    end
                end

                ngx_set_uri(rewrite_uri, true)
            end
        end
    end
    
    return self:exec_action(rule_pass_func)
end

function handler:access()
    -- self._log.err("load exec access")
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