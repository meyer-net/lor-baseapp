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
local n_log = ngx.log
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
local l_object = require("app.lib.classic")

-----> 工具引用
local u_object = require("app.utils.object")
local u_request = require("app.utils.request")
local u_string = require("app.utils.string")
local u_json = require("app.utils.json")
local u_judge = require("app.utils.judge")
local u_extractor = require("app.utils.extractor")
local ue_error = require("app.utils.exception.error")

-----> 外部引用
local c_json = require("cjson.safe")

-----> 必须引用
-----> 业务引用
--------------------------------------------------------------------------

--[[
---> 实例信息及配置
--]]
local handler = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 handler.super.new(self, self._name) or  handler.super.new(self, self._conf, self.store, self._name)
--]]
function handler:new(config, store, name)
    if type(config) == "string" and not store and not name then
        self._name = config
    else 
        -- 指定名称
        self._name = name

        -- 用于操作缓存与DB的对象
        self._store = store
        self._cache = self._store.plugin
    end

    -- 获取基本请求信息抓取对象
    self._request = u_request(self._name)

    -- 当前临时操作数据的仓储
    self._model = {
    	ref_repo = {

    	}
    }
    
    -- 通用事件码
    self._EVENT_CODE = ue_error.EVENT_CODE
end

--------------------------------------------------------------------------

-- 加载下游配置文件
function handler:_load_remote(node, url, args)

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

    args = c_json.encode(args)
    -- args = u_json.to_url_param(args)
    local res, err = http:request_uri(url, {
        method = "POST",
        body = args,
        headers = {
            ["Content-Type"] = "application/json;charset=utf-8"
            -- ["Content-Type"] = "application/x-www-form-urlencoded",
        }
    })

    local body = res and res.body

    if not u_object.check(body) or err then
        n_log(n_err, s_format("[%s-match-%s:error]communication -> url: %s, args: %s, status: %s, err: %s, resp: %s", self._name, node, url, args, res and res.status, err, body))
        return { res = false, status = status, node = node, msg = err, ec = self._EVENT_CODE.api_err }
    end
    
    local resp_body = c_json.decode(body)
    if not u_object.check(resp_body) then
        n_log(n_err, s_format("[%s-match-%s:error]parse json from url: '%s' faild, maybe the url is wrong or the resp it's not formated -> refer to resp: %s", self._name, node, url, body))
        return { res = false, node = node }
    end

    return resp_body
end

-- 通过响应配置文件，获取打印信息
function handler:_get_print_from_ctrl(ctrl_conf, else_conf, ignore_event_code)
    if u_object.check(ctrl_conf.res) then
        return nil
    end

    -- 请求状态错误，直接转换显示
    if ctrl_conf.status then
        return {
            res = false,
            ec = self._EVENT_CODE.api_err,
            msg = s_format("服务器升级中，请稍后再试。%s", ctrl_conf.msg or ""),
            status = ctrl_conf.status
        }
    end
    
    -- 业务逻辑错误，直接转换成print
    if not ignore_event_code and (ctrl_conf.ec and ctrl_conf.ec ~= 0) then
        n_log(n_err, s_format("remote ctrl raise error: %s, uri: %s, request_uri: %s", c_json.encode(ctrl_conf), n_var.uri, n_var.request_uri))
        return ctrl_conf
    end

    -- 未被授权
    return else_conf
end

--------------------------------------------------------------------------

-- 写入日志
function handler:_log( rule, level, text )
    rule = (type(rule) == "boolean" and { log = rule }) or rule
    if rule and u_object.check(rule.log) then
        n_log(level, s_format("=====[%s][%s] -> %s", self._name, self._request.get_client_type(), text))
    end
end

function handler:_filter_rules(sid, pass_func)
    local rules = self._cache:get_json(self._name .. ".selector." .. sid .. ".rules")
    if not rules or type(rules) ~= "table" or #rules <= 0 then
        return false
    end

    for i, rule in ipairs(rules) do
        if rule.enable == true then
            -- judge阶段
            local pass = u_judge.judge_rule(rule, self._name)

            -- extract阶段
            local variables = u_extractor.extract_variables(rule.extractor)

            local is_log = rule.log == true
            -- handle阶段
            if pass then
                self:_log(is_log, n_info, s_format("[MATCH-RULE] %s, host: %s, uri: %s", rule.name, n_var.host, n_var.request_uri))
                
                if pass_func then
                    pass_func(rule, variables)
                end

                return true
            else
                self:_log(is_log, n_info, s_format("[NOT_MATCH-RULE] host: %s, uri: %s", rule.name, n_var.request_uri))
            end
        end
    end

    return false
end

--------------------------------------------------------------------------

function handler:get_name()
    return self._name
end

function handler:exec_action( rule_pass_func )
    local enable = self._cache:get(s_format("%s.enable", self._name))
    local meta = self._cache:get_json(s_format("%s.meta", self._name))
    local selectors = self._cache:get_json(s_format("%s.selectors", self._name))
    local ordered_selectors = meta and meta.selectors
        
    if not u_object.check(enable) or not meta or not ordered_selectors or not selectors then
        return
    end

    for i, sid in ipairs(ordered_selectors) do
        self:_log(true, n_debug, s_format("[PASS THROUGH SELECTOR: %s]", sid))
        local selector = selectors[sid]
        if selector and selector.enable == true then
            local selector_pass 
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector, self._name)-- selector judge
            end
            
            local is_log = selector.handle and selector.handle.log == true
            if selector_pass then
                self:_log(is_log, n_info, s_format("[PASS-SELECTOR: %s] %s", sid, n_var.uri))
                local stop = self:_filter_rules(sid, rule_pass_func)
                if stop then -- 不再执行此插件其他逻辑
                    return
                end
            else
                self:_log(is_log, n_info, "[NOT-PASS-SELECTOR: %s] %s", sid, n_var.uri)
            end

            -- if continue or break the loop
            if selector.handle and selector.handle.continue == true then
                -- continue next selector
            else
                break
            end
        end
    end
end

--------------------------------------------------------------------------

function handler:init_worker()
    n_log(n_debug, " executing plugin \"", self._name, "\": init_worker")
end

function handler:redirect()
    n_log(n_debug, " executing plugin \"", self._name, "\": redirect")
end

function handler:rewrite()
    n_log(n_debug, " executing plugin \"", self._name, "\": rewrite")
end

function handler:access()
    n_log(n_debug, " executing plugin \"", self._name, "\": access")
end

function handler:header_filter()
    n_log(n_debug, " executing plugin \"", self._name, "\": header_filter")
end

function handler:body_filter()
    n_log(n_debug, " executing plugin \"", self._name, "\": body_filter")
    
    --[[
        Nginx 的 upstream 相关模块，以及 OpenResty 的 content_by_lua，会单独发送一个设置了 last_buf 的空 buffer来表示流的结束。
        这算是一个约定俗成的惯例，所以有必要在运行相关逻辑之前，检查 ngx.arg[1] 是否为空。
        当然反过来不一定成立，ngx.arg[2] == true 并不代表 ngx.arg[1] 一定为空。 
        严格意义上，如果只希望 body_filter_by_lua* 修改响应给客户端的内容，需要额外用 ngx.is_subrequest 判断下
    ]]--
    local is_normal_request = u_object.check(ngx.arg[1]) and not ngx.is_subrequest
    if not is_normal_request then
        return
    end
end

function handler:log()
    n_log(n_debug, " executing plugin \"", self._name, "\": log")
end

--------------------------------------------------------------------------

return handler
