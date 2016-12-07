local pairs = pairs
local ipairs = ipairs
local type = type

local u_object = require("app.utils.object")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 循环 操作区域 ----------------------------------------------------------------------------------------------
--[[
---> 用于类型纯JSON无数组 {"test":"123","demo":"xxx"}
--]]
function _M.json_action(json, pair_func)
--- 因使用了pairs，会被解释执行，无法编译成机器码，古此处存在性能缺陷
    for k in pairs(json) do  -- 里层 Keys
        pair_func(k,json[k])
    end
end

--[[
---> 用于数组类型JSON遍历 [{"test":"123","demo":"xxx"}]
--]]
function _M.json_array_action(json_array, pair_func)
    for index in ipairs(json_array) do  -- 外层数组
        local pair = json_array[index]  -- 中层元素

    --- 因使用了pairs，会被解释执行，无法编译成机器码，古此处存在性能缺陷
        for k,v in pairs(pair) do  -- 里层 Keys
            pair_func(k,v)
        end
    end 
end

--[[
---> 用于普通类型，类似集合、数组遍历
--]]
function _M.array_action(array, action)
    for i, v in ipairs(array) do
        action(i,v)
    end
end

--[[
---> 用于批量执行一连串的动作，如果中间操作检测有非bool类型结果返回，则该参数将带入下一次执行条件
--]]
_M.array_function_break = "done_array_function"
function _M.array_function(funcs)
    local not_bool_param = nil
    local err = ""
    for i,action in ipairs(funcs) do
        local result = nil
        if u_object.check(not_bool_param) then
            result,err = action(not_bool_param)
            -- 执行完后参数还原
            not_bool_param = nil
        else
            result,err = action()
        end

        -- 非bool类型结果返回，则记录带入下一次执行条件
        if type(result) ~= "boolean" then
            not_bool_param = result
        end

        -- 执行失败，则返回false
        if not u_object.check(result) then
            return false,err
        end

        -- 执行过程返回function_batch_break值则表示中止后续操作
        if result == _M.function_batch_break then
            return true,err
        end
    end

    return true,err
end

--[[
---> 循环检测是否包含某类型的值
--]]
function _M.check_array_item_type(array,item_type)
    for k,item in ipairs(array) do
        if type(item) ~= item_type then
            return false
        end
    end

    return true
end

--[[
---> 检测对象是否包含在数组中
--]]
function _M.check_array_contains(array, element)
    for _, value in ipairs(array) do
        if value == element then
          return true
        end
    end
    return false
end

--[[
---> 检测元素是否包含在JSON中
示例：utils.check_json_elem_contains(json, {"uri"})
--]]
function _M.check_json_elem_contains(json, elems)
    for _, element in pairs(elems) do
        if json[v] then
            return true
        end
    end

    return false
end

--[[
---> 获取JSON数组匹配的具体项
示例：utils.match_json_array_item(json_array, "uri", "vvv")
--]]
function _M.match_json_array_item(json_array, key, value)
    for _, row in pairs(json_array) do
        local tmp = row[key]
        if u_object.check(tmp) and value == tmp then
            return row
        end
    end

    return nil
end

--[[
-----> 
--]]
--function _M.()
--    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M