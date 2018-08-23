local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local loadstring = loadstring

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO

local t_insert = table.insert
local s_gsub = string.gsub
local u_table = require("app.utils.table")
local u_condition = require("app.utils.condition")

-- 创建一个用于返回操作类的基准对象
local _M = {}

---> 上下文 操作区域 --------------------------------------------------------------------------------------------
---> 转换
function _M.parse_conditions(expression, params)
    if not params or not u_table.is_array(params) or #params == 0 then
        return false
    end

    local new_params = {}
    for i, v in ipairs(params) do
        if v == nil or type(v) ~= "boolean" then
            n_log(n_err, "condition value[", v, "] is nil or not a `boolean` value.")
            return false
        end
        t_insert(new_params, v)
    end

    local u_condition = s_gsub(expression, "(v%[[0-9]+%])", function(m)
        local tmp = s_gsub(m, "v%[([0-9]+)%]", function(n)
            n = tonumber(n)
            return tostring(new_params[n])
        end)
        return tmp
    end)

    if not u_condition or u_condition == "" then return false end

    local trip_allowed_str = u_condition
    local allowed_str = { "true", "false", "not", "and", "or", "%(", "%)", " " }
    for i, v in ipairs(allowed_str) do
        trip_allowed_str = s_gsub(trip_allowed_str, v, "")
    end
    if trip_allowed_str ~= "" then return false end

    if u_condition then
        return true, u_condition
    else
        return false
    end
end

function _M.filter_and_conditions(conditions)
    if not conditions then return false end
    
    local matched_list = {}
    for i, c in ipairs(conditions) do
        local pass, matched = u_condition.judge(c)
        if not pass then
            return false, {}
        end

        t_insert(matched_list, matched)
    end

    return #conditions == #matched_list, matched_list
end

function _M.filter_or_conditions(conditions)
    if not conditions then return false end

    for i, c in ipairs(conditions) do
        local pass, matched = u_condition.judge(c)
        if pass then
            return true, matched
        end
    end

    return false, {}
end

function _M.filter_complicated_conditions(expression, conditions, plugin_name)
    if not expression or expression == "" or not conditions then return false end

    local params = {}
    for i, c in ipairs(conditions) do
        t_insert(params, u_condition.judge(c))
    end

    local ok, u_condition = _M.parse_conditions(expression, params)
    if not ok then return false end

    local pass, match = false
    local func, err = loadstring("return " .. u_condition)
    if not func or err then
        n_log(n_err, "failed to load script: ", u_condition)
        return false
    end

    pass, match = func()
    if pass then
        n_log(n_info, "[", plugin_name or "", "]filter_complicated_conditions: ", expression)
    end

    return pass, match
end

function _M.judge_selector(selector, plugin_name)
    if not selector or not selector.judge then return false end

    local selector_judge = selector.judge
    local judge_type = selector_judge.type
    local conditions = selector_judge.conditions
    
    local selector_pass = false
    if judge_type == 0 or judge_type == 1 then
        selector_pass, match = _M.filter_and_conditions(conditions)
    elseif judge_type == 2 then
        selector_pass, match = _M.filter_or_conditions(conditions)
    elseif judge_type == 3 then
        selector_pass, match = _M.filter_complicated_conditions(selector_judge.expression, conditions, plugin_name)
    end

    return selector_pass
end

function _M.judge_rule(rule, plugin_name)
    if not rule or not rule.judge then return false end
    
    local judge = rule.judge
    local judge_type = judge.type
    local conditions = judge.conditions
    local pass, match = false
    if judge_type == 0 or judge_type == 1 then
        pass, match = _M.filter_and_conditions(conditions)
    elseif judge_type == 2 then
        pass, match = _M.filter_or_conditions(conditions)
    elseif judge_type == 3 then
        pass, match = _M.filter_complicated_conditions(judge.expression, conditions, plugin_name)
    end

    return pass, match
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M
