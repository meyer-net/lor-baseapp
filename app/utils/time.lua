local type = type
local pairs = pairs

local date = require("app.lib.date")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.02' }

---> 时间 操作区域 ----------------------------------------------------------------------------------------------
--[[
---> 获取现在的时间
--]]
function _M.now()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M:%S")
    return result
end

--[[
---> 
--]]
function _M.current_timetable()
    local n = date()
    local yy, mm, dd = n:getdate()
    local h = n:gethours()
    local m = n:getminutes()
    local s = n:getseconds()
    local day = yy .. "-" .. mm .. "-" .. dd
    local hour = day .. " " .. h
    local minute = hour .. ":" .. m
    local second = minute .. ":" .. s
    
    return {
        Day = day,
        Hour = hour,
        Minute = minute,
        Second = second
    }
end

--[[
---> 
--]]
function _M.current_second()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M:%S")
    return result
end

--[[
---> 
--]]
function _M.current_minute()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M")
    return result
end

--[[
---> 
--]]
function _M.current_hour()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H")
    return result
end

--[[
---> 
--]]
function _M.current_day()
    local n = date()
    local result = n:fmt("%Y-%m-%d")
    return result
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M