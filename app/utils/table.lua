local pairs = pairs
local ipairs = ipairs
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local t_insert = table.insert

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

---> 复制并合并表
function _M.clone_merge (t, m)
    local new = _M.clone(t)
    for k, v in pairs(m) do
        new[k] = v
    end

    return new
end

---> 是否包含
function _M.contains(t, element)
    for _, value in pairs(t) do
        if value == element then
          return true
        end
    end

    return false
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

---> 
function _M.reverse(t)  
    local tmp = {}  
    for i = 1, #t do  
        local key = #t  
        tmp[i] = table.remove(t)  
    end  
  
    return tmp  
end

---> 清理字段
function _M.clean_fields(t, fields)
    for _,field in ipairs(fields) do
        t[field] = nil
    end  
  
    return t  
end

---> 保留字段
function _M.keep_fields(t, fields, binds)
    binds = binds or {}
    for k,v in pairs(binds) do
        t[k] = t[v]
    end

    for _ in pairs(t) do
        if not _M.contains(fields, _) and not binds[_] then
            t[_] = nil
        end
    end
  
    return t  
end    

---> 重命名字段
function _M.rename_fields(t, renames)
    local res_data = {}
    for k,v in pairs(t) do
        local new_name = renames[k]
        if new_name then
            res_data[new_name] = t[k]
        end
    end

    return res_data
end 

---> 转换为哈希表
function _M.to_hash(t, key)
    local t_hash = {}
    for i, v in ipairs(t) do
        local t_key = tostring(v[key])
        v[key] = nil
        t_hash[t_key] = v
    end

    return t_hash
end

---> 转换为数组
function _M.to_array(t)
    if not _M.is_array(t) then
        local tmp = {}
        table.insert(tmp, t)
        return tmp
    end

    return t
end

--[[ 存在部分问题，先废弃
-- 将 来源表格 中所有键及值复制到 目标表格 对象中，如果存在同名键，则覆盖其值
-- example
    local source = { c = 3, d = 4 }
    local dest = { a = 1, b = 2 }
    u_table.merge(source, dest)
    -- dest = { a = 1, b = 2, c = 3, d = 4 }
    u_table.merge({
                    payload = ident_payload
                  }, http_uri_args)
-- @param dest 目标表格(t表示是table)
-- @param source 来源表格(t表示是table)
--]]
function _M.merge( source, dest )
    source = source or {}
    
    if _M.is_empty(dest) then
        return source
    end

    local merge = _M.clone(dest)
    
    if not _M.is_array(source) then
        for k, v in pairs(source) do
            merge[k] = v
        end
    else
        for _, v in ipairs(source) do
            if not _M.contains(merge, v) then
                t_insert(merge, v)
            end
        end
    end

    return merge
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-- https://blog.csdn.net/humanxing/article/details/42318213
-- local SWITCH_METATABLE = {
-- 	__index = function(t, k) 
-- 		return rawget(t, "__default")
-- 	end,
-- }
-- function SwitchGenerator(tbl)
-- 	tbl = tbl or {}
-- 	setmetatable(tbl, SWITCH_METATABLE)
-- 	return function(case)
-- 		return tbl[case]()
-- 	end, tbl

-----------------------------------------------------------------------------------------------------------------

return _M