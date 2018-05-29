--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_lower = string.lower
local s_match = string.match
local s_find = string.find
local s_len = string.len
local s_sub = string.sub

local n_req = ngx.req

local n_var = ngx.var
local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

-----> 基础库引用
local l_object = require("app.lib.classic")

-----> 工具引用
local u_each = require("app.utils.each")
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")

-----> 外部引用
local multipart = require("multipart")
local c_json = require("cjson.safe")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local obj = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 api.super.new(self, self._name)
--]]
function obj:new(name)
    self._name = s_format("[%s]-request", name or self._name)
end

---> 上下文 公有变量 ---------------------------------------------------------------------------------------------

local CONTENT_TYPE = "content-type"
local CONTENT_LENGTH = "content-length"

local DEFAULT_CONTENT_TYPE_VALUE = "application/x-www-form-urlencoded"
local CONTENT_TYPE_MULTI_PART = "multipart/form-data"
local CONTENT_TYPE_APP_JSON = "application/json"
local CONTENT_TYPE_APP_XFORM_URL = DEFAULT_CONTENT_TYPE_VALUE

local APP_JSON, MULTI_PART, X_FORM_URL_ENCODED = "json", "multipart", "xform_url_encoded"
local HTTP_METHOD = {
    POST = "POST",
    GET = "GET"
}

-----------------------------------------------------------------------------------------------------------------

--- 匹配并返回指定值
local function match_return( source, exp, value )
    return s_find(source, exp, nil, true) and value
end

--- 匹配上下文类型
local function match_trans_type(content_type)
    local lower_content_type = content_type:lower()
    return content_type and (match_return(lower_content_type, CONTENT_TYPE_APP_JSON, APP_JSON) or
                             match_return(lower_content_type, CONTENT_TYPE_MULTI_PART, MULTI_PART) or
                             match_return(lower_content_type, CONTENT_TYPE_APP_XFORM_URL, X_FORM_URL_ENCODED))
end

-----------------------------------------------------------------------------------------------------------------

function obj:transform_headers_to_body (trans_type, new_body, body, content_type_value)
    body = body and body or ""
    local content_length = s_len(body)
    local is_body_transed = false

    local switch = {
        [APP_JSON] = function ()
            local parameters = c_json.decode(body)
            if parameters == nil and content_length > 0 then return false, nil end -- Couldn't modify body
            
            if content_length > 0 then
                for body_name, body_value in pairs(new_body) do
                    if type(body_value) == "table" then
                        body_value = c_json.encode(body_value)
                    end

                    parameters[body_name] = body_value
                    is_body_transed = true
                end
            end
            return is_body_transed, c_json.encode(parameters)
        end,
        [MULTI_PART] = function ()
            if not s_find(content_type_value:lower(), "; boundary=----", nil, true) then
                return false, body, "Missing boundary in multipart/form-data POST data in Unknown on line 0"
            end

            local parameters = multipart(body, content_type_value)
            if parameters == nil and content_length > 0 then return false, nil end -- Couldn't modify body

            -- if content_length > 0 then
                u_each.json_action(new_body, function ( body_name, body_value )
                    if type(body_value) == "table" then
                        body_value = c_json.encode(body_value)
                    end
                    
                    parameters:set_simple(body_name, body_value)
                    is_body_transed = true
                end)
            -- end
            
            return is_body_transed, parameters:tostring()
        end,
        [X_FORM_URL_ENCODED] = function ()
            local parameters = ngx.decode_args(body)
            if parameters == nil and content_length > 0 then return false, nil end -- Couldn't modify body

            if content_length >= 0 then
                for body_name, body_value in pairs(new_body) do
                    if type(body_value) == "table" then
                        body_value = c_json.encode(body_value)
                    end
                    
                    parameters[body_name] = body_value
                    is_body_transed = true
                end
            end

            return is_body_transed, ngx.encode_args(parameters)
        end
    }

    local switch_trans_func = switch[trans_type]
    if not new_body or not switch_trans_func then
        return false, body
    end

    return switch_trans_func()
end

--------------------------------------------------------------------------

--[[
---> 追加数据实体
--]]
function obj:transform_post(new_body)
    local method = s_lower(n_req.get_method())

    if method == "get" then
        local args = n_req.get_uri_args()
        -- args.ident_id = ident_id
        n_req.set_uri_args(args)
            
        return true
    else
        local content_type_value = n_req.get_headers(0)[CONTENT_TYPE]
        if not content_type_value then
            content_type_value = DEFAULT_CONTENT_TYPE_VALUE
            n_req.set_header("Content-Type", content_type_value)
        end

        n_req.read_body()
        local body = n_req.get_body_data()

        local trans_type = match_trans_type(content_type_value)
        local is_body_transed, body, err = self:transform_headers_to_body(trans_type, new_body, body, content_type_value)
        
-- n_log(n_err, "---------------------------------------------")
-- n_log(n_err, is_body_transed)
-- n_log(n_err, body)
-- n_log(n_err, err)
-- n_log(n_err, content_type_value)
-- n_log(n_err, "---------------------------------------------")
        if is_body_transed and not err then
            n_req.set_body_data(body)
            n_req.set_header(CONTENT_LENGTH, s_len(body))
        end

        return is_body_transed, err
    end
end

--[[
---> 获取客户端真实ID
--]]
function obj:get_client_host()
    local headers = n_req.get_headers()  
    return headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
end

--[[
---> 判断请求协议
--]]
function obj:is_https_protocol()
    -- local server_protocol = n_var.server_protocol
    -- n_log(n_err, server_protocol:lower())
    -- return server_protocol and (match_return(server_protocol:lower(), "https", true) or false)
    return n_var.scheme:lower() == "https"
end

--[[
---> 获取客户端浏览器类型
--]]
function obj:get_client_type()
    -- 99% 前三个都能匹配上吧
    local arr_mobile = {
        "phone",
        "android",
        "mobile",
        "itouch",
        "ipod",
        "symbian",
        "htc",
        "palmos",
        "blackberry",
        "opera mini",
        "windows ce",
        "nokia",
        "fennec",
        "hiptop",
        "kindle",
        "mot",
        "webos",
        "samsung",
        "sonyericsson",
        "wap",
        "avantgo",
        "eudoraweb",
        "minimo",
        "netfront",
        "teleca",
        "unknow"
    }

    local lower_user_agent = s_lower(n_var.http_user_agent or "unknow")

    u_each.array_action(arr_mobile, function ( _, v )
        if s_match(lower_user_agent, v) then
            return v
        end
    end)

    return "browser"
end
--[[
---> 
--]]
--function obj:()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return obj