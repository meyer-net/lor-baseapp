local t_insert = table.insert
local t_concat = table.concat

local u_object = require("app.utils.object")
local u_each = require("app.utils.each")
local u_table = require("app.utils.table")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

--[[
---> JSON 单列值的合并
例如：[{"path":"\/http_cache"}] 
====> { "http_cache" }
--]]
function _M.json_value_combine(json)
    local array = {}
    u_each.json_array_action(json, function(k,v)
        t_insert(array, v)
    end)
    return array
end

--[[
---> JSON 某字段值合并
例如：[{tag:1, "path":"\/http_cache"},{tag:1, "path":"\/http_action"}] 
====> { tag:1, "path_list": ["\/http_cache", "\/http_action"] }
--]]
function _M.json_field_value_combine(json, combine_field)
    local ret_obj = {}
    local combine_obj = {}

    u_each.json_array_action(json, function(k,v)
        -- 如果是合并的列
        if k == combine_field then
            t_insert(combine_obj, v)
        else
            ret_obj[k] = v
        end
    end)

    -- 合并的列，插入到主表中
    ret_obj[combine_field.."_list"] = combine_obj

    return ret_obj
end

--[[
---> JSON 指定某些字段值的对比
--]]
function _M.json_compare_assign(json_source, json_dest, assign_fields)
    local cal_count = 0
    local total_count = 0

    if u_object.check(json_source) and u_object.check(json_dest) then
        u_each.json_action(json_source, function(k,v)
            -- 如果不在排除的列时
            if assign_fields and u_table.contains(assign_fields, k) then

                -- 如果值相等
                if v == json_dest[k] then
                    cal_count = cal_count + 1
                end
            end

            total_count = total_count + 1
        end)
    end

    return #(except_fields or {}) == cal_count, cal_count
end

--[[
---> JSON 排除某些字段值对比
--]]
function _M.json_compare_except(json_source, json_dest, except_fields)
    local cal_count = 0
    local is_same = true

    if u_object.check(json_source) and u_object.check(json_dest) then
        u_each.json_action(json_source, function(k,v)
            -- 如果不在排除的列时
            if not except_fields or not u_table.contains(except_fields, k) then

                -- 如果值相等
                if tostring(v) == tostring(json_dest[k]) then
                    cal_count = cal_count + 1
                else
                    -- ngx.log(ngx.ERR, string.format("%s -> %s(%s), %s(%s), %s", k, v, type(v), json_dest[k], type(json_dest[k]), v == json_dest[k]))
                    is_same = false
                    return is_same
                end
            end
        end)
    end

    return is_same, cal_count
end

--[[
-----> 
例如：[{"path":"\/http_cache"}] => "http_cache"
--]]
function _M.json_field_value_combine_to_string(json, spliter)
    if not spliter then
        spliter = ""
    end

    local array = _M.json_field_value_combine(json)

    return t_concat(array, spliter)
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M