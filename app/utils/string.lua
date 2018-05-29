local tostring = tostring
local type = type

local s_gsub = string.gsub
local s_find = string.find
local s_sub = string.sub
local s_reverse = string.reverse
local s_rep = string.rep
local m_floor = math.floor
local t_insert = table.insert

local date = require("app.lib.date")
local l_uuid = require("app.lib.uuid")
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

--[[
---> 功能：分割字符串
---> URL：http://www.cnblogs.com/xdao/p/lua_string_function.html
---> 参数：带分割字符串，分隔符
---> 返回：字符串表
--]]
function _M.split(source, delimiter)
    if not source or source == "" then return {} end
    if not delimiter or delimiter == "" then return { source } end
    
    local array = {}
    for match in (source..delimiter):gmatch("(.-)"..delimiter) do
        t_insert(array, match)
    end
    return array
end

--[[
---> 字符串分割，第二种方式
--]]
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
---> 功能：统计字符串中字符的个数
---> 返回：总字符个数、英文字符数、中文字符数
--]]
function _M.count(source)
  local tmpStr=source
  local _,sum=s_gsub(source,"[^\128-\193]","")
  local _,countEn=s_gsub(tmpStr,"[%z\1-\127]","")

  return sum,countEn,sum-countEn
end

--[[
---> 功能：计算字符串的宽度，这里一个中文等于两个英文
--]]
function _M.width(source)
  local _,en,cn=_M.count(source)
  return cn*2+en
end

--[[
---> 功能: 把字符串扩展为长度为len,居中对齐, 其他地方以filled_chr补齐
---> 参数: source 需要被扩展的字符、数字、字符串表，len 被扩展成的长度，
--->       filled_chr填充字符，可以为空
--]]
function _M.tocenter(source, len, filled_chr)
  local function tocenter(source,len,filled_chr)
      source = tostring(source);
      filled_chr = filled_chr or " ";
      local nRestLen = len - _M.width(source); -- 剩余长度
      local nNeedCharNum = m_floor(nRestLen / _M.width(filled_chr)); -- 需要的填充字符的数量
      local nLeftCharNum = m_floor(nNeedCharNum / 2); -- 左边需要的填充字符的数量
      local nRightCharNum = nNeedCharNum - nLeftCharNum; -- 右边需要的填充字符的数量
       
      source = s_rep(filled_chr, nLeftCharNum)..source..s_rep(filled_chr, nRightCharNum); -- 补齐
      return source
  end

  if type(source)=="number" or type(source)=="string" then
      if not s_find(tostring(source),"\n") then
        return tocenter(source,len,filled_chr)
      else
        source=string.split(source,"\n")
      end
  end

  if type(source)=="table" then
    local tmpStr=tocenter(source[1],len,filled_chr)
    for i=2,#source do
      tmpStr=tmpStr.."\n"..tocenter(source[i],len,filled_chr)
    end
    return tmpStr
  end

end

--[[
---> 功能: 把字符串扩展为长度为len,左对齐, 其他地方用filled_chr补齐
--]]
function _M.pad_right(source, len, filled_chr)
  local function toleft(source, len, filled_chr)
    source = tostring(source);
    filled_chr = filled_chr or " ";
    local nRestLen = len - _M.width(source);        -- 剩余长度
    local nNeedCharNum = m_floor(nRestLen / _M.width(filled_chr)); -- 需要的填充字符的数量
     
    source = source..s_rep(filled_chr, nNeedCharNum);     -- 补齐
    return source;
  end

  if type(source)=="number" or type(source)=="string" then
    if not s_find(tostring(source),"\n") then
      return toleft(source,len,filled_chr)
    else
      source=string.split(source,"\n")
    end
  end

  if type(source)=="table" then
    local tmpStr=toleft(source[1],len,filled_chr)
    for i=2,#source do
      tmpStr=tmpStr.."\n"..toleft(source[i],len,filled_chr)
    end
    return tmpStr
  end
end

--[[
---> 功能: 把字符串扩展为长度为len,右对齐, 其他地方用filled_chr补齐
--]]
function _M.pad_left(source, len, filled_chr)
  local function toright(source, len, filled_chr)
    source = tostring(source);
    filled_chr = filled_chr or " ";
    local nRestLen = len - _M.width(source);        -- 剩余长度
    local nNeedCharNum = m_floor(nRestLen / _M.width(filled_chr)); -- 需要的填充字符的数量
     
    source = s_rep(filled_chr, nNeedCharNum).. source;     -- 补齐
    return source;
  end
  if type(source)=="number" or type(source)=="string" then
      if not s_find(tostring(source),"\n") then
        return toright(source,len,filled_chr)
      else
        source=string.split(source,"\n")
      end
  end
  if type(source)=="table" then
    local tmpStr=toright(source[1],len,filled_chr)
    for i=2,#source do
      tmpStr=tmpStr.."\n"..toright(source[i],len,filled_chr)
    end
    return tmpStr
  end
end

--[[
---> 
--]]
function _M.ltrim(source)
    return s_gsub(source, "^[ \t\n\r]+", "")
end

--[[
---> 
--]]
function _M.rtrim(source, ends)
    ends = ends or "\t\n\r"
    return s_gsub(source, "[ "..ends.."]+$", "")
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
function _M.trim_uri_args( uri )
    local from, to, err = ngx.re.find(uri, "\\?", 'isjo')

    if from and to and from == to and not err then
        return s_sub(uri, 0, to - 1)
    end

    return uri
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
    return l_uuid():gsub("-", "")
end

--[[
---> 
--]]
function _M.gen_new_id()
    return l_uuid()
end

--[[
---> 
--]]
function _M.to_date(date_string)
    local Y = s_sub(date_string, 1, 4)  
    local M = s_sub(date_string, 6, 7)  
    local D = s_sub(date_string, 9, 10)  

    return os.date({ 
        year=Y, 
        month=M, 
        day=D}) 
end

--[[
---> 
--]]
function _M.to_time(time_string)
    local Y = s_sub(time_string, 1, 4)  
    local M = s_sub(time_string, 6, 7)  
    local D = s_sub(time_string, 9, 10)  

    local HH = s_sub(time_string, 12, 13) or 0
    local MM = s_sub(time_string, 15, 16) or 0
    local SS = s_sub(time_string, 18, 19) or 0

    return os.time({ 
        year=Y, 
        month=M, 
        day=D, 
        hour=HH,
        min=MM,
        sec=SS}) 
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M