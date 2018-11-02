--
--[[
---> 插件处理器基础类
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
-- from https://github.com/Mashape/kong/blob/master/kong/plugins/base_plugin.lua
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require

local s_format = string.format

local n_var = ngx.var

local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local r_http = require("resty.http")

-----> 工具引用
local m_base = require("app.model.base_model")
local u_request = require("app.utils.request")
local u_context = require("app.utils.context")

-----> 外部引用
--

-----> 必须引用
--

-----> 业务引用
local r_plugin = require("app.model.repository.plugin_repo")

--------------------------------------------------------------------------

--[[
---> 实例信息及配置
--]]
local handler = m_base:extend()

--------------------------------------------------------------------------

handler.utils.handle = require("app.utils.handle")
handler.utils.judge = require("app.utils.judge")
handler.utils.extractor = require("app.utils.extractor")

--------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 handler.super.new(self, self._name) or handler.super.new(self, self._conf, self.store, self._name)
--]]
function handler:new(conf, store, name, opts)
    if type(conf) == "string" and not store and not name then
        name = conf
        conf = nil
        store = nil
    end

    -- 传导值进入父类
    handler.super.new(self, conf, store, name, opts)
    
    -- 重新转向缓存
    self._cache_using = self._store.cache.using

    -- 当前缓存构造器
    self._cache = self._store.plugin

    -- 获取基本请求信息抓取对象
    self._request = u_request(self._name)
    
    -- 引用
    self.model = {
    	current_repo = r_plugin(conf, store, self._source),
    	ref_repo = {
            
    	}
	}
end

--------------------------------------------------------------------------

-- 加载下游配置文件
function handler:_load_remote(node, method, headers, url, args)

    -- local content_type = ngx.req.get_headers(0)["Content-Type"]
    -- ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")
    -- local res, err = ngx.location.capture("/capture_proxy", {
    --     method = ngx.HTTP_POST,
    --     body = args,
    --     vars = {
    --         capture_proxy_host = host,
    --         capture_proxy_uri = uri
    --     }
    -- })
    -- ngx.req.set_header("Content-Type", content_type)
    -- local body = res.status == ngx.HTTP_OK and res.body
    local http = r_http.new()

    args = self.utils.json.encode(args)
    -- args = u_json.to_url_param(args)
    headers["content-length"] = string.len(args)
    local res, err = http:request_uri(url, {
        method = method,
        body = args,
        headers = headers
    })

    local body = ""
    if res then
        body = res.body
        ngx.status = res.status
    end

    if not self.utils.object.check(body) or err then
        self._log.err("[%s-match-%s:error]communication -> url: %s, args: %s, status: %s, err: %s, resp: %s", self._name, node, url, args, res and res.status, err, body)
        return { res = false, status = ngx.status, node = node, msg = err, ec = self.utils.ex.error.EVENT_CODE.api_err }
    end
    
    local resp_body = self.utils.json.decode(body)
    if not self.utils.object.check(resp_body) then
        self._log.err("[%s-match-%s:error]parse json from url: '%s' faild, maybe the url is wrong or the resp it's not formated -> refer to resp: %s", self._name, node, url, body)
        return { res = false, status = ngx.status, node = node, msg = "body can't decode", ec = self.utils.ex.error.EVENT_CODE.api_err }
    end

    return resp_body
end

-- 通过响应配置文件，获取打印信息
function handler:_get_print_from_ctrl(ctrl_conf, else_conf, ignore_event_code)
    if self.utils.object.check(ctrl_conf.res) then
        return nil
    end

    -- 请求状态错误，直接转换显示
    if ctrl_conf.status then
        return {
            res = false,
            ec = self.utils.ex.error.EVENT_CODE.api_err,
            msg = "服务器升级中，请稍后再试",
            desc = ctrl_conf.msg,
            status = ctrl_conf.status
        }
    end
    
    -- 业务逻辑错误，直接转换成print
    if not ignore_event_code and (ctrl_conf.ec and ctrl_conf.ec ~= 0) then
        self._log.err("remote ctrl raise error: %s, uri: %s, request_uri: %s", self.utils.json.encode(ctrl_conf), n_var.uri, n_var.request_uri)
        return ctrl_conf
    end

    -- 未被授权
    return else_conf
end

--------------------------------------------------------------------------

-- 覆写日志函数
function handler:check_rule_log(rule)
    rule = (type(rule) == "boolean" and { handle = { log = rule } }) or rule
    return rule and self.utils.object.check(rule.handle.log)
end

function handler:rule_log_err(rule, text)
    if self:check_rule_log(rule) then
        return self._log.err("=====[%s][%s] -> %s", self._name, self._request.get_client_type(), text)
    end
end

function handler:rule_log_info(rule, text)
    if self:check_rule_log(rule) then
        return self._log.info("=====[%s][%s] -> %s", self._name, self._request.get_client_type(), text)
    end
end

function handler:rule_log_debug(rule, text)
    if self:check_rule_log(rule) then
        return self._log.debug("=====[%s][%s] -> %s", self._name, self._request.get_client_type(), text)
    end
end

--------------------------------------------------------------------------

function handler:_rule_action(rule, pass_func, rule_failure_func)
    local pass, conditions_matched = false, {}
    if rule.enable then
        -- judge阶段
        pass, conditions_matched = self.utils.judge.judge_rule(rule, self._name)

        -- extract阶段
        local variables = self.utils.extractor.extract_variables(rule.extractor)
        
        local is_log = rule.handle.log == true
        -- handle阶段
        if pass then
            self:rule_log_info(is_log, s_format("*****[%s-MATCH-RULE] %s*****: conditions_matched: %s, host: %s, uri: %s", self._name, rule.name, self.utils.json.encode(conditions_matched), n_var.host, n_var.request_uri))
            
            if pass_func then
                pass_func(self, rule, variables, conditions_matched)
            else
                self:rule_log_err(is_log, s_format("*****[%s-MATCH-RULE] %s*****: not contains [action], host: %s, uri: %s", self._name, rule.name, n_var.host, n_var.request_uri))
            end
        else
            self:rule_log_info(is_log, s_format("*****[%s-NOT_MATCH-RULE]*****: host: %s, uri: %s", self._name, rule.name, n_var.request_uri))
        end
    end

    return pass, conditions_matched
end

--[[
---> 当前插件具备一定特殊性，重写父类规则
--]]
function handler:_stop_check(continue, check_passed)
    -- ngx.log(ngx.ERR, self.format("%s|%s|%s|%s",rule.name,check_passed, self.utils.json.encode(rule_failure_func), self.utils.json.encode(rule.judge)))
    if type(continue) ~= "boolean" then
        local switch = {
            -- 匹配则略过后续规则
            [0] = function ( )
                return check_passed
            end
        }
        
        local _switch_stop_check = switch[continue or 0]
        if _switch_stop_check then
            return _switch_stop_check()
        end
    end
    
    return check_passed or not continue --handler.super._stop_check(self, rule, check_passed)
end

--------------------------------------------------------------------------

function handler:get_name()
    return self._name
end

function handler:combine_micro_handle_by_rule(rule, variables)
    local n_var_uri = n_var.uri
    local n_var_host = n_var.host

    local handle = rule.handle
    if rule.type == 1 then
        if handle.micro then
            local micro = self.model.current_repo:get_rule("micros", handle.micro)
            
            if not micro or not micro.value then
                self:rule_log_err(rule, self.format("[%s-%s] can not find micro '%s'. host: %s, uri: %s", self._name, rule.name, handle.micro, n_var_host, n_var_uri))
                return
            end

            local micro_value = self.utils.json.decode(micro.value)
            if not micro_value or not micro_value.handle then
                self:rule_log_err(rule, self.format("[%s-%s] can not parser micro '%s' from value '%s'. host: %s, uri: %s", self._name, rule.name, handle.micro, micro_value, n_var_host, n_var_uri))
                return
            end

            handle = micro_value.handle
        else
            handle = {}
        end
    end
    
    local extractor_type = rule.extractor.type
    local handle_host = handle.host
    if not handle_host or handle_host == "" then -- host默认取请求的host
        handle_host = n_var_host
    else 
        handle_host = self.utils.handle.build_upstream_host(extractor_type, handle_host, variables, self._name)
    end

    handle.host = handle_host
    handle.url = self.utils.handle.build_upstream_url(extractor_type, handle.url, variables, self._name)

    self:rule_log_info(rule, self.format("[%s-%s] extractor_type: %s, host: %s, url: %s", self._name, rule.name, extractor_type, handle.host, handle.url))

    return handle
end

function handler:check_exec_rule( rules, rule_pass_func)
    local rule_stop = false
    self.utils.each.array_action(rules, function ( _, rule )
        -- 指示规则验证通过
        local rule_passed, conditions_matched = self:_rule_action(rule, rule_pass_func)

        rule_stop = self:_stop_check(rule.handle.continue, rule_passed) 
        
        -- 匹配到插件 或 略过后续规则时跳出
        return not rule_stop -- 循环跳出，each接受false时才会跳出
    end)

    return rule_stop
end

function handler:exec_action( rule_pass_func, rule_failure_func )
    if not rule_pass_func then
        return
    end

    local enable = ngx.ctx[s_format("_plugin_%s.enable", self._name)]
    local meta = ngx.ctx[s_format("_plugin_%s.meta", self._name)]
    local selectors = ngx.ctx[s_format("_plugin_%s.selectors", self._name)]

    local ordered_selectors = meta and meta.selectors

    if not self.utils.object.check(enable) or not meta or not ordered_selectors or not selectors then
        return
    end
    
    self.utils.each.array_action(ordered_selectors, function ( i, sid )
        self:rule_log_debug(is_log, s_format("[PASS THROUGH SELECTOR: %s]", sid))
        local selector = selectors[sid]
        
        if selector and selector.enable == true then
            local selector_pass 
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = self.utils.judge.judge_selector(selector, self._name)-- selector judge
            end

            local rule_stop = false
            local is_log = selector.handle and selector.handle.log == true
            if selector_pass then
                self:rule_log_info(is_log, s_format("[PASS-SELECTOR: %s] %s", sid, n_var.uri))
                
                local rules = ngx.ctx[s_format("_plugin_%s.selector.%s.rules", self._name, sid)]
                          
                if rules and type(rules) == "table" and #rules > 0 then
                    local rule_stop = self:check_exec_rule(rules, rule_pass_func)
    
                    if rule_stop then -- 不再执行此插件其他逻辑
                        return false
                    end
                end
            else
                self:rule_log_debug(is_log, s_format("[NOT-PASS-SELECTOR: %s] %s", sid, n_var.uri))
            end

            -- if continue or break the loop
            return not self:_stop_check(selector.handle and selector.handle.continue, rule_stop) -- 跳过当前插件的后续选择器
        end
    end)
end

--------------------------------------------------------------------------

function handler:exec_filter(filter_action)
    if not filter_action or not u_request:check_context_content_type_can_be_filter() then
        return
    end

    local chunk, eof = ngx.arg[1] or "", ngx.arg[2]  -- 获取当前的流 和是否时结束
    local info = ngx.ctx.tmp_body
    
    if info then
        ngx.ctx.tmp_body = info .. chunk -- 这个可以将原本的内容记录下来
    else
        ngx.ctx.tmp_body = chunk
    end
    
    if eof then
        filter_action(ngx.ctx.tmp_body)
    else
        ngx.arg[1] = nil -- 这里是为了将原本的输出不显示
    end
end

--------------------------------------------------------------------------

-- 该函数解决在执行阶段上下文不适配REDIS缓存的问题
function handler:_init_cache_to_ctx()
    local enable_cache_name = s_format("%s.enable", self._name)
    local enable = self._cache:get_bool(enable_cache_name)
    ngx.ctx["_plugin_"..enable_cache_name] = enable

    local meta_cache_name = s_format("%s.meta", self._name)
    local meta = self._cache:get_json(meta_cache_name)
    ngx.ctx["_plugin_"..meta_cache_name] = meta

    local selectors_cache_name = s_format("%s.selectors", self._name)
    local selectors = self._cache:get_json(selectors_cache_name)
    ngx.ctx["_plugin_"..selectors_cache_name] = selectors

    local ordered_selectors = meta and meta.selectors

    if not self.utils.object.check(enable) or not meta or not ordered_selectors or not selectors then
        return
    end
    
    for i, sid in ipairs(ordered_selectors) do
        self:rule_log_debug(is_log, s_format("[PASS THROUGH SELECTOR: %s]", sid))
        local selector = selectors[sid]
        
        if selector and selector.enable == true then
            local rules_cache_name = s_format("%s.selector.%s.rules", self._name, sid)
            local rules = self._cache:get_json(rules_cache_name) 
            ngx.ctx["_plugin_"..rules_cache_name] = rules
        end
    end                
end

function handler:init_worker()
    self._slog.debug("executing plugin %s: init_worker", self._name)
end

function handler:redirect()
    self._log.debug("executing plugin %s: redirect", self._name)
end

function handler:rewrite()
    self._log.debug("executing plugin %s: rewrite", self._name)
end

function handler:access()
    self._log.debug("executing plugin %s: access", self._name)
end

function handler:header_filter()
    self._log.debug("executing plugin %s: header_filter", self._name)
end

function handler:body_filter()
    --[[
        Nginx 的 upstream 相关模块，以及 OpenResty 的 content_by_lua，会单独发送一个设置了 last_buf 的空 buffer来表示流的结束。
        这算是一个约定俗成的惯例，所以有必要在运行相关逻辑之前，检查 ngx.arg[1] 是否为空。
        当然反过来不一定成立，ngx.arg[2] == true 并不代表 ngx.arg[1] 一定为空。 
        严格意义上，如果只希望 body_filter_by_lua* 修改响应给客户端的内容，需要额外用 ngx.is_subrequest 判断下
    ]]--
    local is_normal_request = self.utils.object.check(ngx.arg[1]) and not ngx.is_subrequest
    if not is_normal_request then
        return
    end

    self._log.debug("executing plugin %s: body_filter", self._name)
end

function handler:log()
    self._log.debug("executing plugin %s: log", self._name)
end

--------------------------------------------------------------------------

return handler