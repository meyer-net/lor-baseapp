local pairs = pairs
local ipairs = ipairs
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable

-- 创建一个用于返回操作类的基准对象
local _M = {}

---> TABLE 操作区域 ---------------------------------------------------------------------------------------------
---> 复制表
function _M.clone (t)
    local lookup_table = {}
    local function _copy(t)
        if type(t) ~= "table" then
            return t
        elseif lookup_table[t] then
            return lookup_table[t]
        end
        local newObject = {}
        lookup_table[t] = newObject
        for key, value in pairs(t) do
            newObject[_copy(key)] = _copy(value)
        end
        return setmetatable(newObject, getmetatable(t))
    end
    return _copy(t)
end

---> 表是否为空
function _M.is_empty(t)
    if t == nil or _G.next(t) == nil then
        return true
    else
        return false
    end
end

---> 表是否是数组
function _M.is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

---> 表压缩成参数
function _M.compose(t, params)
    if t==nil or params==nil or type(t)~="table" or type(params)~="table" or #t~=#params+1 or #t==0 then
        return nil
    else
        local result = t[1]
        for i=1, #params do
            result = result  .. params[i].. t[i+1]
        end
        return result
    end
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M