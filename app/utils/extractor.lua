local type = type
local ipairs = ipairs

local n_log = ngx.log
local n_err = ngx.ERR

local s_find = string.find
local s_lower = string.lower
local t_insert = table.insert
local ngx_re_match = ngx.re.match

---> 内部公用 操作区域 --------------------------------------------------------------------------------------------
---> 提取参数
local function extract_variable(extraction)
    if not extraction or not extraction.type then
        return ""
    end

    local etype = extraction.type
    local result = ""

    local switch = {
        ["URI"] = function() -- 为简化逻辑，URI模式每次只允许提取一个变量
            local uri = ngx.var.uri
            local m, err = ngx_re_match(uri, extraction.name)
            if not err and m and m[1] then
                result = m[1] -- 提取第一个匹配的子模式
            end
        end,
        ["Query"] = function()
            local query = ngx.req.get_uri_args()
            result = query[extraction.name]
        end,
        ["Header"] = function()
            local headers = ngx.req.get_headers()
            result = headers[extraction.name]
        end,
        ["PostParams"] = function()
            local headers = ngx.req.get_headers()
            local header = headers['Content-Type']
            if header then
                local is_multipart = s_find(header, "multipart")
                if is_multipart and is_multipart > 0 then
                    return false
                end
            end
            ngx.req.read_body()
            local post_params, err = ngx.req.get_post_args()
            if not post_params or err then
                ngx.log(ngx.ERR, "[Extract Variable]failed to get post args: ", err)
                return false
            end
            result = post_params[extraction.name]
        end,
        ["Host"] = function()
            result = ngx.var.host
        end,
        ["IP"] = function()
            result =  ngx.var.remote_addr
        end,
        ["Method"] = function()
            local method = ngx.req.get_method()
            result = s_lower(method)
        end
    }

    local action = switch[etype]
    if action then 
        action()
    end

    return result
end

---> 提取参数
local function extract_variable_for_template(extractions)
    if not extractions then
        return {}
    end

    local result = {}
    local ngx_var = ngx.var
    local switch = {
        ["URI"] = function(extraction) -- URI模式通过正则可以提取出N个值
            result["uri"] = {} -- fixbug: nil `uri` variable for tempalte parse
            local uri = ngx_var.uri
            local m, err = ngx_re_match(uri, extraction.name)
            if not err and m and m[1] then
                if not result["uri"] then result["uri"] = {} end
                for j, v in ipairs(m) do
                    if j >= 1 then
                        result["uri"]["v" .. j] = v
                    end
                end
            end
        end,
        ["Query"] = function(extraction)
            local query = ngx.req.get_uri_args()
            if not result["query"] then result["query"] = {} end
            result["query"][extraction.name] = query[extraction.name] or extraction.default
        end,
        ["Header"] = function(extraction)
            local headers = ngx.req.get_headers()
            if not result["header"] then result["header"] = {} end
            result["header"][extraction.name]  = headers[extraction.name] or extraction.default
        end,
        ["PostParams"] = function(extraction)
            local headers = ngx.req.get_headers()
            local header = headers['Content-Type']
            local ok = true
            if header then
                local is_multipart = s_find(header, "multipart")
                if is_multipart and is_multipart > 0 then
                    ok = false
                end
            end
            ngx.req.read_body()
            local post_params, err = ngx.req.get_post_args()
            if not post_params or err then
                ngx.log(ngx.ERR, "[Extract Variable]failed to get post args: ", err)
                ok = false
            end

            if ok then
                if not result["body"] then result["body"] = {} end
                result["body"][extraction.name] = post_params[extraction.name] or extraction.default
            end
        end,
        ["Host"] = function(extraction)
            result["host"] = ngx_var.host or extraction.default
        end,
        ["IP"] = function(extraction)
            result["ip"] =  ngx_var.remote_addr or extraction.default
        end,
        ["Method"] = function(extraction)
            local method = ngx.req.get_method()
            result["method"] = s_lower(method)
        end
    }

    for i, extraction in ipairs(extractions) do
        local etype = extraction.type

        local action = switch[etype]
        if action then 
            action(extraction)
        end
    end

    return result
end

-- 创建一个用于返回操作类的基准对象
local _M = {}

---> 上下文 操作区域 --------------------------------------------------------------------------------------------
---> 展开
function _M.extract(extractor_type, extractions)
    if not extractions or type(extractions) ~= "table" or #extractions < 1 then
        return {}
    end

    if not extractor_type then
        extractor_type = 1
    end

    local result = {}
    local switch = {
        [1] = function() -- simple variables extractor
            for i, extraction in ipairs(extractions) do
                local variable = extract_variable(extraction) or extraction.default or ""
                t_insert(result, variable)
            end
        end,
        [2] = function() -- tempalte variables extractor
            result = extract_variable_for_template(extractions)
        end
    }

    switch[extractor_type]()

    return result
end

---> 展开
function _M.extract_variables(extractor)
    if not extractor then return {} end
    
    local extractor_type = extractor.type
    local extractions = extractor and extractor.extractions
    local variables
    if extractions then
        variables = _M.extract(extractor_type, extractions)
    end

    return variables
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M