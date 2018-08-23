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
local r_cookie = require("resty.cookie")
local p_base = require("app.plugins.handler_adapter")

-----> 工具引用
local u_jwt = require("app.utils.jwt")
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
    self.PRIORITY = 0

    -- 插件名称
    self._source = "filter"

	-- 传导至父类填充基类操作对象
	handler.super.new(self, conf, store)
end

-----------------------------------------------------------------------------------------------------------------

function handler:_header_filter_action(rule, variables, conditions_matched)
    local n_var = ngx.var
    local n_var_host = n_var.host
    local n_var_uri = n_var.uri

    local handle = rule.handle
    if handle and #handle.header > 0 then
        self.utils.each.array_action(handle.header, function ( _, filter )
            ngx.header[filter.key] = filter.value or nil
        end)

        self:rule_log_err(rule, self.format("[%s-%s] execute header filter. host: %s, uri: %s", self._name, rule.name, n_var_host, n_var_uri))
    else
        self:rule_log_err(rule, self.format("[%s-%s] takes no header filter. host: %s, uri: %s", self._name, rule.name, n_var_host, n_var_uri))
    end
end

function handler:_body_filter_action(rule, variables, conditions_matched)
    -- self._log.err("load exec header_filter")
    -- local resp_body = ngx.arg[1]
    -- local is_normal_request = self.utils.object.check(ngx.arg[1]) and not ngx.is_subrequest
    -- if not is_normal_request then
    --     return
    -- end
 
    local n_var = ngx.var
    local n_var_host = n_var.host
    local n_var_uri = n_var.uri

    local handle = rule.handle
    if handle and #handle.body > 0 then
        local switch = {
            [0] = function ( payload_string )
                ngx.header["Content-Type"] = "application/json; charset=utf-8"
                local payload = self.utils.json.decode(payload_string)
                if not self.utils.object.check(payload) then
                    self._log.err("[%s-%s]parse payload faild, maybe the url is wrong or the resp it's not formated by jwt -> refer to resp: %s", self._name, rule.name, payload_string)
                    return { res = false, status = ngx.status, msg = "body can't decode", ec = self.utils.ex.error.EVENT_CODE.api_err }
                end

                local c_jwt = u_jwt(self._name, self._cache_using)
                local secret, jwt_val = c_jwt:generate(payload)
                local ok, err = self._cache_using:set(secret, jwt_val)

                if ok and not err then
                    -- 写入COOKIE则不通过body响应
                    local join_cookie = false
                    if u_object.check(join_cookie) then
                        -- ***??? 存在BUG，会重复写入客户端。(原因 httponly模式 会写入浏览器，而服务端会出现加载不到的情况)
                        local c_request = u_request(self._name)
                        local cookie = r_cookie:new()
                        local cookie_module = {
                            domain = n_var.host,
                            path = "/", 
                            secure = c_request:is_https_protocol(),
                            samesite = "Strict",
                            extension = payload.csrf_token,
                            expires = ngx.cookie_time(payload.exp)
                        }

                        local ok, err = cookie:set(self.utils.table.clone_merge(cookie_module, {
                            key = rule_handle.ident_field,
                            value = jwt_val,
                            httponly = true
                        }))
                        
                        -- CSRF令牌
                        cookie:set(self.utils.table.clone_merge(cookie_module, {
                            key = "csrf_token",
                            value = payload.csrf_token,
                            httponly = false
                        }))
                        
                        return {}
                    else
                        return { 
                            csrf_token = payload.csrf_token,
                            jwt = jwt_val
                        }
                    end
                end
            end
        }
        self.utils.each.array_action(handle.body, function ( _, filter )
            local filter_func = switch[filter.type]
            if not filter_func then
                self:rule_log_err(rule, self.format("[%s-%s] filter of '%s' can not find . host: %s, uri: %s", self._name, rule.name, filter.type, n_var_host, n_var_uri))
                return
            end

            local filter_val = filter_func(resp_body)

            ngx.arg[1] = self.utils.json.encode(filter_val)
        end)

        self:rule_log_debug(rule, self.format("[%s-%s] execute body filter. host: %s, uri: %s", self._name, rule.name, n_var_host, n_var_uri))
    else
        self:rule_log_err(rule, self.format("[%s-%s] takes no body filter. host: %s, uri: %s", self._name, rule.name, n_var_host, n_var_uri))
    end
end

-----------------------------------------------------------------------------------------------------------------

function handler:body_filter()
    self:exec_action(self._body_filter_action)
end

function handler:header_filter()
    self:exec_action(self._header_filter_action)
end

-----------------------------------------------------------------------------------------------------------------

return handler