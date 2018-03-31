local t_insert = table.insert
local t_concat = table.concat

local u_table = require("app.utils.table")

local c_json = require("cjson.safe")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 对象 操作区域 ----------------------------------------------------------------------------------------------
--[[
---> 对象是否为空
--]]
function _M.check(obj)
    if (type(obj) == "table" and u_table.is_empty(obj)) then
        return false
    end

    return obj ~= false and obj ~= 0 and obj ~= "" and obj ~= nil and obj ~= ngx.null and obj ~= {} and obj ~= "{}"
end

--[[
---> 空则默认设置
--]]
function _M.set_if_empty(obj, default)
    local ret_val = obj
    if not _M.check(obj) then
        if type(default) == "function" then
            ret_val = default()
        else
            ret_val = default
        end
    end

    return ret_val
end

--[[
---> 创建一个对象
--]]
function _M.create(self)
    local obj = {}
    function obj:new()
        local instance = {}
        setmetatable(instance, { __index = self})
        return instance
    end

    return obj
end

--[[
---> 对象转换为JSON
--]]
function _M.to_json(obj)
    if type(obj) == "table" then
        obj = c_json.encode(obj)
    end

    return obj
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M