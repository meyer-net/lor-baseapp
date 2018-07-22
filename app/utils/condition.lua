local type = type

local n_log = ngx.log
local n_err = ngx.ERR

local s_format = string.format
local s_find = string.find
local s_lower = string.lower
local s_sub = string.sub
local ngx_re_find = ngx.re.find

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 内部公用 操作区域 --------------------------------------------------------------------------------------------
---> 条件断言
local function assert_condition(real, operator, expected)
    if not real then
        n_log(n_err, s_format("assert_condition error: %s %s %s", real, operator, expected))
        return false
    end

    local switch = { 
        ['match'] = function()
            local from, to, err = ngx_re_find(real, expected, 'isjo')
            if from ~= nil then
                return true, s_sub(real, from, to)
            end
        end,
        ['not_match'] = function()
            local from, to, err = ngx_re_find(real, expected, 'isjo')
            if from == nil then
                return true
            end
        end,
        ['='] = function()
            if real == expected then
                return true
            end
        end,
        ['!='] = function()
            if real ~= expected then
                return true
            end
        end,
        ['>'] = function()
            if real ~= nil and expected ~= nil then
                expected = tonumber(expected)
                real = tonumber(real)
                if real and expected and real > expected then
                    return true
                end
            end
        end,
        ['>='] = function()
            if real ~= nil and expected ~= nil then
                expected = tonumber(expected)
                real = tonumber(real)
                if real and expected and real >= expected then
                    return true
                end
            end
        end,
        ['<'] = function()
            if real ~= nil and expected ~= nil then
                expected = tonumber(expected)
                real = tonumber(real)
                if real and expected and real < expected then
                    return true
                end
            end
        end,
        ['<='] = function()
            if real ~= nil and expected ~= nil then
                expected = tonumber(expected)
                real = tonumber(real)
                if real and expected and real <= expected then
                    return true
                end
            end
        end
    }

    local action = switch[operator]
    if not action then 
        return false, real
    end

    local result, match = action()
    return result, match or real
end

---> 上下文 操作区域 --------------------------------------------------------------------------------------------
---> 条件判断
function _M.judge(condition)
    local condition_type = condition and condition.type
    if not condition_type then
        return false
    end

    local operator = condition.operator
    local expected = condition.value
    if not operator or not expected then
        return false
    end

    local real
    local switch = {
        ["URI"] = function()
            real = ngx.var.uri
        end,
        ["Query"] = function()
            local query = ngx.req.get_uri_args()
            real = query[condition.name]
        end,
        ["Header"] = function()
            local headers = ngx.req.get_headers()
            real = headers[condition.name]
        end,
        ["IP"] = function()
            real =  ngx.var.remote_addr
        end,
        ["UserAgent"] = function()
            real =  ngx.var.http_user_agent
        end,
        ["Method"] = function()
            local method = ngx.req.get_method()
            method = s_lower(method)
            if not expected or type(expected) ~= "string" then
                expected = ""
            end
            expected = s_lower(expected)
            real = method
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
                n_log(n_err, "[Condition Judge]failed to get post args: ", err)
                return false
            end
    
            real = post_params[condition.name]
        end,
        ["Referer"] = function()
            real =  ngx.var.http_referer
        end,
        ["Host"] = function()
            real =  ngx.var.host
        end
    }

    local action = switch[condition_type]
    if action then 
        action()
    end

    return assert_condition(real, operator, expected)
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M