local s_gsub = string.gsub
local s_find = string.find
local s_reverse = string.reverse
local t_insert = table.insert

local date = require("app.lib.date")
local uuid = require("app.lib.uuid")
local r_sha256 = require("resty.sha256")
local r_string = require("resty.string")
local ngx_quote_sql_str = ngx.quote_sql_str

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.02' }

---> 字符串 操作区域 --------------------------------------------------------------------------------------------
---> 字符串SHA256编码
function _M.encode(s)
    local sha256 = r_sha256:new()
    sha256:update(s)
    local digest = sha256:final()
    return r_string.to_hex(digest)
end

---> 消除转义
function _M.clear_slash(s)
    s, _ = s_gsub(s, "(/+)", "/")
    return s
end

---> 转义为安全的字符串
function _M.secure(str)
    return ngx_quote_sql_str(str)
end

---> 字符串分割
function _M.split(source, delimiter)
    if not source or source == "" then return {} end
    if not delimiter or delimiter == "" then return { source } end
    
    local array = {}
    for match in (source..delimiter):gmatch("(.-)"..delimiter) do
        t_insert(array, match)
    end
    return array
end

---> 字符串分割，第二种方式
function _M.split_gsub(source, delimiter)
    if not source or source == "" then return {} end
    if not delimiter or delimiter == "" then return { source } end

    local array = {}
    s_gsub(source, '[^'..delimiter..']+', function(tmp) 
        t_insert(array, tmp) 
    end)

    return array
end

--[[
---> 
--]]
function _M.trim(source)  
    return s_gsub(source, "^%s*(.-)%s*$", "%1")
end

--[[
---> 
--]]
function _M.trim_all(source)
    if not source or source == "" then return "" end
    local result = s_gsub(source, " ", "")
    return result
end

--[[
-----> 
--]]
function _M.strip(source)
    if not source or source == "" then return "" end
    local result = s_gsub(source, "^ *", "")
    result = s_gsub(result, "( *)$", "")
    return result
end

--[[
-----> 
--]]
function _M.match_ip(source)
    local _,_,ip = s_find(source, "(%d+%.%d+%.%d+%.%d+)")
    return ip
end

--[[
---> 
--]]
function _M.starts_with(source, substr)
    if source == nil or substr == nil then
        return false
    end
    if s_find(source, substr) ~= 1 then
        return false
    else
        return true
    end
end

--[[
---> 
--]]
function _M.ends_with(source, substr)
    if source == nil or substr == nil then
        return false
    end
    local str_reverse = s_reverse(source)
    local substr_reverse = s_reverse(substr)
    if s_find(str_reverse, substr_reverse) ~= 1 then
        return false
    else
        return true
    end
end

--[[
-----> 
--]]
function _M.match_wrape_with(source, left, right)
    local _,_,ret_text = s_find(source, left.."(.-)"..right)
    return ret_text
end

--[[
-----> 
--]]
function _M.match_ends_with(source, ends_text)
    local _,_,ret_text = s_find(source, ".+("..ends_text..")")
    return ret_text
end 

--[[
-----> 进行字符串分隔，
例如 _M.get_split_string_item(ngx.var.uri, "/", 1)
--]]
function _M.get_split_string_item(source, delimiter, get_index)
    if not (source and delimiter) then
        return nil
    end
    
    local temp_index = 1
    local item_value = nil
    s_gsub(source, '[^'..delimiter..']+', function(tmp)
        if temp_index == get_index then
            item_value = tmp
            return
        end 
        temp_index = temp_index + 1
    end, get_index)

    return item_value
end

--[[
---> 
--]]
function _M.gen_random_string()
    return uuid():gsub("-", "")
end

--[[
---> 
--]]
function _M.gen_new_id()
    return uuid()
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M