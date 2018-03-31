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
function _M.get_date( time )
    if not time then
        return date()
    end

    return date(time)
end

--[[
---> 
--]]
function _M.current_timetable(time)
    local n = _M.get_date(time)
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
        Second = second,
        YY = yy,
        MM = mm,
        DD = dd
    }
end

--[[
---> 
--]]
function _M.current_second(time, fmt)
    local n = _M.get_date(time)
    local result = n:fmt(fmt or "%Y-%m-%d %H:%M:%S")
    return result
end

--[[
---> 
--]]
function _M.current_minute(time, fmt)
    local n = _M.get_date(time)
    local result = n:fmt(fmt or "%Y-%m-%d %H:%M")
    return result
end

--[[
---> 
--]]
function _M.current_hour(time, fmt)
    local n = _M.get_date(time)
    local result = n:fmt(fmt or "%Y-%m-%d %H")
    return result
end

--[[
---> 
--]]
function _M.current_day(time, fmt)
    local n = _M.get_date(time)
    local result = n:fmt(fmt or "%Y-%m-%d")
    return result
end

--[[
---> 
--]]
function _M.to_string(time_int)
  -- body
  return os.date("%Y-%m-%d %H:%M:%S", time_int)
end

--[[
---> 
--]]
function _M.create_time(src_time, interval, date_unit)
    --从日期字符串中截取出年月日时分秒
    local Y = s_sub(src_time, 1, 4)  
    local M = s_sub(src_time, 6, 7)  
    local D = s_sub(src_time, 9, 10)  

    local HH = s_sub(src_time, 12, 13) or 0
    local MM = s_sub(src_time, 15, 16) or 0
    local SS = s_sub(src_time, 18, 19) or 0
  
    --把日期时间字符串转换成对应的日期时间  
    local data_time = os.time{ year=Y, month=M, day=D, hour=H, min=MM, sec=SS }  
  
    --根据时间单位和偏移量得到具体的偏移数据  
    local switch_offset = {
        ['DAY'] = function ( )
            return 60 * 60 * 24 * interval
        end,
        ['HOUR'] = function ( )
            return 60 * 60 * interval
        end,
        ['MINUTE'] = function ( )
            return 60 * interval
        end,
        ['SECOND'] = function ( )
            return interval
        end
    }
  
    --指定的时间+时间偏移量  
    local offset = switch_offset[date_unit]()
    return os.date("*t", data_time + tonumber(offset))
end

--[[
---> 将时间转换为指定参照日期格式
--]]
function _M.convert_time_to_date( src_time, target_date )
    local ret_date = _M.get_date(src_time)
    if type(src_time) == "string" and #src_time <= 8 then
        local target_date = _M.get_date(target_date)
        local yy, mm, dd = target_date:getdate()
        ret_date:setyear(yy, mm, dd)
    end
    
    return ret_date
end

--[[
---> 检测时间是否在某个区间内
---> u_time.check_time_in_range('14:30:00', '19:00:00')
--]]
function _M.check_time_in_range(time_begin, time_end, src_time)
    src_time = _M.get_date(src_time)
    time_begin = _M.convert_time_to_date(time_begin, src_time)
    time_end = _M.convert_time_to_date(time_end, src_time)

    local res_begin_date = date.diff(src_time, time_begin)
    local res_end_date = date.diff(time_end, src_time)

    return res_begin_date:spanticks() >=0 and res_end_date:spanticks() >= 0
end

--[[
---> 获取单元选择器
---> u_time.get_switch_unit('m')
---> clean_mode 表示清0模式，例如h则不计算分，秒，m则不计算时，秒
--]]
function _M.get_switch_unit(time_unit, clean_mode)
    time_unit = time_unit or "s"
    local switch_unit = {
        ["d"] = function(d)
            -- if clean_mode then
            --     d:sethours(0, 0, 0, 0)
            -- end
            return d:spandays()
        end,
        ["h"] = function(d)
            -- if clean_mode then
            --     -- sethours(num_hour, num_min, num_sec, num_ticks)
            --     d:sethours(d:gethours(), 0, 0, 0)
            -- end
            return d:spanhours()
        end,
        ["m"] = function(d)
            -- if clean_mode then
            --     -- setminutes(num_min, num_sec, num_ticks)
            --     d:setminutes(d:getminutes(), 0, 0)
            -- end
            return d:spanminutes()
        end,
        ["s"] = function(d)
            -- if clean_mode then
            --     -- setseconds(num_sec, num_ticks)
            --     d:setseconds(d:getseconds(), 0)
            -- end
            return d:spanseconds()
        end,
        ["t"] = function(d)
            return d:spanticks()
        end
    }

    return switch_unit[time_unit]
end

--[[
---> 检测时间超出多少单位，calc_time未设定则表示当前时间
---> u_time.get_time_less('14:30:00', 'h', '19:00:00')
---> clean_mode 表示清0模式，例如h则不计算分，秒，m则不计算时，秒
--]]
function _M.get_time_passed(base_time, time_unit, calc_time, clean_mode)
    calc_time = _M.get_date(calc_time)
    base_time = _M.convert_time_to_date(base_time, calc_time)

    local res_date = date.diff(calc_time, base_time)

    return _M.get_switch_unit(time_unit, clean_mode)(res_date)
end

--[[
---> 检测时间剩余多少单位，calc_time未设定则表示当前时间
---> u_time.get_time_less('14:30:00', 'h', '19:00:00')
---> clean_mode 表示清0模式，例如h则不计算分，秒，m则不计算时，秒
--]]
function _M.get_time_less(base_time, time_unit, calc_time, clean_mode)
    calc_time = _M.get_date(calc_time)
    base_time = _M.convert_time_to_date(base_time, calc_time)

    local res_date = date.diff(base_time, calc_time)

    return _M.get_switch_unit(time_unit, clean_mode)(res_date)
end

--[[
---> 检测时间是否在某个区间内剩余单位
---> u_time.get_time_less('14:30:00', '19:00:00')
---> 若src_time没在区间内则返回-1
--]]
function _M.get_time_less_in_array(time_begin, time_end, less_unit, src_time)
    local res_begin_unit = _M.get_time_passed(time_begin, src_time)
    local res_end_unit = _M.get_time_less(time_end, src_time)

    if res_begin_unit >=0 and res_end_unit >= 0 then
        return math.abs(res_end_unit)
    end

    return -1
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M