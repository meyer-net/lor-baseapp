-- 
--[[
---> 对请求体进行一定操作
--------------------------------------------------------------------------
---> 参考文献如下
-----> 
--------------------------------------------------------------------------
---> Examples：
-----> 请求体追加参数：
local trans_ok, trans_err = self._request:transform_post({
    payload = ident_payload
})

if trans_err then
    case_error_exit(ue_error.get_err(self.utils.ex.error.EVENT_CODE.param_format_err, err))
end
--]]
--
-----------------------------------------------------------------------------------------------------------------
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

local t_concat = table.concat
local t_insert = table.insert

local n_req = ngx.req

local n_var = ngx.var
local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

-----> 基础库引用
local u_base = require("app.utils.base")

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
local _obj = u_base:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 api.super.new(self, self._name)
--]]
function _obj:new(name)
    local name = s_format("[%s]-request", name or self._name)

	-- 传导至父类填充基类操作对象
    _obj.super.new(self, name)
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

--升级版(能处理content-type=multipart/form-data的表单)：
local function explode ( _str,seperator )
    local pos, arr = 0, {}
        for st, sp in function() return s_find( _str, seperator, pos, true ) end do
            t_insert( arr, s_sub( _str, pos, st-1 ) )
            pos = sp + 1
        end
    t_insert( arr, s_sub( _str, pos ) )
    return arr
end

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

function _obj:transform_headers_to_body (trans_type, new_body, body, content_type_value)
    body = body and body or ""
    new_body = new_body or {}
    local content_length = s_len(body)
    local is_body_transed = false

    if content_length == 0 then
        return false, body
    end

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
    if not switch_trans_func then
        return false, body
    end

    return switch_trans_func()
end

--------------------------------------------------------------------------

--[[
---> 数据转换为JSON
in: body -> string
--]]
function _obj:get_transform_json(body)
    local args = {}
    --判断是否是multipart/form-data类型的表单      
    local content_type_value = n_req.get_headers(0)[CONTENT_TYPE]
    local trans_type = self:get_trans_type(content_type_value)
    if trans_type == MULTI_PART then
        if not body then
            local datafile = ngx.req.get_body_file()
            if not datafile then
                error_code = 1
                error_msg = "no request body found"
            else
                local fh, err = io.open(datafile, "r")
                if not fh then
                    error_code = 2
                    error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err)
                else
                    fh:seek("set")
                    body = fh:read("*a")
                    fh:close()
                    if body == "" then
                        error_code = 3
                        error_msg = "request body is empty"
                    end
                end
            end
        end  
        --确保取到请求体的数据
        if not error_code then
            local boundary = "--" .. s_sub(content_type_value, 31)
            local body_table = explode(body,boundary)
            local first_string = table.remove(body_table, 1)
            local last_string = table.remove(body_table)
            for i,v in ipairs(body_table) do
                local start_pos,end_pos,capture,capture2 = s_find(v,'Content%-Disposition: form%-data; name="(.+)"; filename="(.*)"')
                --普通参数
                if not start_pos then
                    local t = explode(v,"\r\n\r\n")
                    local temp_param_name = s_sub(t[1], 41, -2)
                    local temp_param_value = s_sub(t[2], 1, -3)
                    args[temp_param_name] = temp_param_value
                end
            end
        end
    else
        args = c_json.decode(body)
    end

    return args
end

--[[
---> 获取类型
--]]
function _obj:get_trans_type(content_type_value)
    if not content_type_value then
        content_type_value = DEFAULT_CONTENT_TYPE_VALUE
        n_req.set_header(CONTENT_TYPE, content_type_value)
    end

    return match_trans_type(content_type_value)
end

--[[
---> 追加数据实体
--]]
function _obj:get_transform_post(new_body)
    local content_type_value = n_req.get_headers(0)[CONTENT_TYPE]
    local trans_type = self:get_trans_type(content_type_value)

    n_req.read_body()
    local body = n_req.get_body_data()

    -- is_body_transed, body, err
    return self:transform_headers_to_body(trans_type, new_body, body, content_type_value)
end

--[[
---> 追加数据实体
--]]
function _obj:transform_body(new_body)
    local method = s_lower(n_req.get_method())

    if method == "get" then
        local args = n_req.get_uri_args()
        -- args.ident_id = ident_id
        n_req.set_uri_args(args)
            
        return true
    else
        local is_body_transed, body, err = self:get_transform_post(new_body)
        
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
function _obj:get_client_host()
    local headers = n_req.get_headers()  
    return headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
end

--[[
---> 判断请求协议
--]]
function _obj:is_https_protocol()
    -- local server_protocol = n_var.server_protocol
    -- n_log(n_err, server_protocol:lower())
    -- return server_protocol and (match_return(server_protocol:lower(), "https", true) or false)
    return n_var.scheme:lower() == "https"
end

--[[
---> 获取客户端浏览器类型
--]]
function _obj:get_client_type()
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
---> 获取请求uri的扩展名
--]]
function _obj:get_ext_by_uri(uri)
    uri = uri or n_var.uri
    local uri_ext_match, uri_ext_err = ngx.re.match(uri, '(\\.(\\w+)\\?)|(\\.(\\w+)$)')
    return (uri_ext_match and not uri_ext_err) and uri_ext_match[0]
end

--[[
---> 检测请求uri是否包含扩展名
--]]
function _obj:check_ext(uri)
    return uri:match(".+()%.%w+$")
end

--[[
---> 依据扩展名获取CONTENT-TYPE类型
--]]
function _obj:get_content_type_by_ext(ext)
    local ext_ct_dict = {
        [""] = "text/html", 
        [".html"] = "text/html", 
        [".htm"] = "text/html", 
        [".shtml"] = "text/html", 
        [".css"] = "text/css", 
        [".xml"] = "text/xml", 
        [".gif"] = "image/gif", 
        [".jpeg"] = "image/jpeg", 
        [".jpg"] = "image/jpeg", 
        [".js"] = "application/javascript", 
        [".atom"] = "application/atom+xml", 
        [".rss"] = "application/rss+xml", 
        [".mml"] = "text/mathml", 
        [".txt"] = "text/plain", 
        [".jad"] = "text/vnd.sun.j2me.app-descriptor", 
        [".wml"] = "text/vnd.wap.wml", 
        [".htc"] = "text/x-component", 
        [".png"] = "image/png", 
        [".tif"] = "image/tiff", 
        [".tiff"] = "image/tiff", 
        [".wbmp"] = "image/vnd.wap.wbmp", 
        [".ico"] = "image/x-icon", 
        [".jng"] = "image/x-jng", 
        [".bmp"] = "image/x-ms-bmp", 
        [".svg"] = "image/svg+xml", 
        [".svgz"] = "image/svg+xml", 
        [".webp"] = "image/webp", 
        [".woff"] = "application/font-woff", 
        [".jar"] = "application/java-archive", 
        [".war"] = "application/java-archive", 
        [".ear"] = "application/java-archive", 
        [".json"] = "application/json", 
        [".hqx"] = "application/mac-binhex40", 
        [".doc"] = "application/msword", 
        [".pdf"] = "application/pdf", 
        [".ps"] = "application/postscript", 
        [".eps"] = "application/postscript", 
        [".ai"] = "application/postscript", 
        [".rtf"] = "application/rtf", 
        [".m3u8"] = "application/vnd.apple.mpegurl", 
        [".xls"] = "application/vnd.ms-excel", 
        [".eot"] = "application/vnd.ms-fontobject", 
        [".ppt"] = "application/vnd.ms-powerpoint", 
        [".wmlc"] = "application/vnd.wap.wmlc", 
        [".kml"] = "application/vnd.google-earth.kml+xml", 
        [".kmz"] = "application/vnd.google-earth.kmz", 
        [".7z"] = "application/x-7z-compressed", 
        [".cco"] = "application/x-cocoa", 
        [".jardiff"] = "application/x-java-archive-diff", 
        [".jnlp"] = "application/x-java-jnlp-file", 
        [".run"] = "application/x-makeself", 
        [".pl"] = "application/x-perl", 
        [".pm"] = "application/x-perl", 
        [".prc"] = "application/x-pilot", 
        [".pdb"] = "application/x-pilot", 
        [".rar"] = "application/x-rar-compressed", 
        [".rpm"] = "application/x-redhat-package-manager", 
        [".sea"] = "application/x-sea", 
        [".swf"] = "application/x-shockwave-flash", 
        [".sit"] = "application/x-stuffit", 
        [".tcl"] = "application/x-tcl", 
        [".tk"] = "application/x-tcl", 
        [".der"] = "application/x-x509-ca-cert", 
        [".pem"] = "application/x-x509-ca-cert", 
        [".crt"] = "application/x-x509-ca-cert", 
        [".xpi"] = "application/x-xpinstall", 
        [".xhtml"] = "application/xhtml+xml", 
        [".xspf"] = "application/xspf+xml", 
        [".zip"] = "application/zip", 
        [".bin"] = "application/octet-stream", 
        [".exe"] = "application/octet-stream", 
        [".dll"] = "application/octet-stream", 
        [".deb"] = "application/octet-stream", 
        [".dmg"] = "application/octet-stream", 
        [".iso"] = "application/octet-stream", 
        [".img"] = "application/octet-stream", 
        [".msi"] = "application/octet-stream", 
        [".msp"] = "application/octet-stream", 
        [".msm"] = "application/octet-stream", 
        [".mid"] = "audio/midi", 
        [".midi"] = "audio/midi", 
        [".kar"] = "audio/midi", 
        [".mp3"] = "audio/mpeg", 
        [".ogg"] = "audio/ogg", 
        [".m4a"] = "audio/x-m4a", 
        [".ra"] = "audio/x-realaudio", 
        [".3gpp"] = "video/3gpp", 
        [".3gp"] = "video/3gpp", 
        [".ts"] = "video/mp2t", 
        [".mp4"] = "video/mp4", 
        [".mpeg"] = "video/mpeg", 
        [".mpg"] = "video/mpeg", 
        [".mov"] = "video/quicktime", 
        [".webm"] = "video/webm", 
        [".flv"] = "video/x-flv", 
        [".m4v"] = "video/x-m4v", 
        [".mng"] = "video/x-mng", 
        [".asx"] = "video/x-ms-asf", 
        [".asf"] = "video/x-ms-asf", 
        [".wmv"] = "video/x-ms-wmv", 
        [".avi"] = "video/x-msvideo", 
        [".apk"] = "application/vnd.android.package-archive",
        [".ipa"] = "application/vnd.android.package-archive",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document", 
        [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
        [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    }

    return ext_ct_dict[ext]
end

--[[
---> 获取静态的CONTENT-TYPE类型
--]]
function _obj:get_static_content_type()
    local content_type_value = n_req.get_headers(0)[CONTENT_TYPE] or self:get_content_type_by_ext(self:get_ext_by_uri())
    if not u_object.check(content_type_value) then
        return ""
    end
    
    local lower_content_type = content_type_value:lower()
    local static_mime_types = {
        "text/html", 
        "text/css", 
        "text/xml", 
        "image/gif", 
        "image/jpeg", 
        "application/javascript", 
        "application/atom+xml", 
        "application/rss+xml", 
        "text/mathml", 
        "text/plain", 
        "text/vnd.sun.j2me.app-descriptor", 
        "text/vnd.wap.wml", 
        "text/x-component", 
        "image/png", 
        "image/tiff", 
        "image/vnd.wap.wbmp", 
        "image/x-icon", 
        "image/x-jng", 
        "image/x-ms-bmp", 
        "image/svg+xml", 
        "image/webp", 
        "application/font-woff", 
        "application/java-archive", 
        "application/mac-binhex40", 
        "application/msword", 
        "application/pdf", 
        "application/postscript", 
        "application/rtf", 
        "application/vnd.apple.mpegurl", 
        "application/vnd.ms-excel", 
        "application/vnd.ms-fontobject", 
        "application/vnd.ms-powerpoint", 
        "application/vnd.wap.wmlc", 
        "application/vnd.google-earth.kml+xml", 
        "application/vnd.google-earth.kmz", 
        "application/x-7z-compressed", 
        "application/x-cocoa", 
        "application/x-java-archive-diff", 
        "application/x-java-jnlp-file", 
        "application/x-makeself", 
        "application/x-perl", 
        "application/x-pilot", 
        "application/x-rar-compressed", 
        "application/x-redhat-package-manager", 
        "application/x-sea", 
        "application/x-shockwave-flash", 
        "application/x-stuffit", 
        "application/x-tcl", 
        "application/x-x509-ca-cert", 
        "application/x-xpinstall", 
        "application/xhtml+xml", 
        "application/xspf+xml", 
        "application/zip", 
        "application/octet-stream", 
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document", 
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
        "application/vnd.openxmlformats-officedocument.presentationml.presentation", 
        "audio/midi", 
        "audio/mpeg", 
        "audio/ogg", 
        "audio/x-m4a", 
        "audio/x-realaudio", 
        "video/3gpp", 
        "video/mp2t", 
        "video/mp4", 
        "video/mpeg", 
        "video/quicktime", 
        "video/webm", 
        "video/x-flv", 
        "video/x-m4v", 
        "video/x-mng", 
        "video/x-ms-asf", 
        "video/x-ms-wmv", 
        "video/x-msvideo"
    }

    local match_type = ""
    u_each.array_action(static_mime_types, function ( i, ct )
        match_type = match_return(lower_content_type, ct, ct)
        if u_object.check(match_type) then
            return false
        end
    end)

    return match_type
end

--[[
---> 获取静态的CONTENT-TYPE类型
--]]
function _obj:check_context_content_type_is_text()
    local content_type_value = n_req.get_headers(0)[CONTENT_TYPE] or self:get_content_type_by_ext(self:get_ext_by_uri())
    if not u_object.check(content_type_value) then
        return true
    end
    
    local lower_content_type = content_type_value:lower()
    local static_mime_types = {
        "text/html", 
        "text/css", 
        "text/xml", 
        "application/javascript", 
        "application/atom+xml", 
        "application/rss+xml", 
        "text/mathml", 
        "text/plain", 
        "text/vnd.sun.j2me.app-descriptor", 
        "text/vnd.wap.wml", 
        "text/x-component"
    }

    local matched = false
    u_each.array_action(static_mime_types, function ( i, ct )
        match_type = match_return(lower_content_type, ct, ct)
        matched = u_object.check(match_type)
        if matched then
            return false
        end
    end)

    return matched
end

--[[
---> 获取静态的CONTENT-TYPE类型
--]]
function _obj:check_context_content_type_can_be_filter()
    local content_type_value = n_req.get_headers(0)[CONTENT_TYPE] or self:get_content_type_by_ext(self:get_ext_by_uri())
    if not u_object.check(content_type_value) then
        return true
    end
    
    local lower_content_type = content_type_value:lower()
    local static_mime_types = {
        "text/html", 
        "text/xml", 
        -- "application/javascript", 
        "application/atom+xml", 
        "application/rss+xml", 
        "text/mathml", 
        "text/plain", 
        "text/vnd.sun.j2me.app-descriptor", 
        "text/vnd.wap.wml", 
        "text/x-component"
    }

    local matched = false
    u_each.array_action(static_mime_types, function ( i, ct )
        match_type = match_return(lower_content_type, ct, ct)
        if match_type == "text/css" then
            ngx.log(ngx.ERR, "3333333333333333333333333333333")
        end
        matched = u_object.check(match_type)
        if matched then
            return false
        end
    end)

    return matched
end

--[[
---> 
--]]
--function _obj:()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _obj