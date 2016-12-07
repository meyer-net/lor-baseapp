local t_insert = table.insert
local t_concat = table.concat

local u_table = require("app.utils.table")

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
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M