local ipairs = ipairs
local type = type
local t_insert = table.insert

local u_table = require("app.utils.table")
local u_string = require("app.utils.string")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 数据库 操作区域 --------------------------------------------------------------------------------------------
--[[
---> 转义SQL语句
--]]
function _M.parse_sql(sql, params)
    if not params or not u_table.is_array(params) or #params == 0 then
        return sql
    end

    local new_params = {}
    for i, v in ipairs(params) do
        if v and type(v) == "string" then
            v = u_string.secure(v)
        end
        
        t_insert(new_params, v)
    end

    local t = u_string.split(sql,"?")
    local sql = u_table.compose(t, new_params)

    return sql
end 

--[[
---> 过滤结果集
--]]
function _M.filter_records(opts, records)
    -- 判断是否有结果，执行逻辑动作
    local value
    local records_len = #(records)
    local is_records_nil = records_len == 0
    if is_records_nil and opts.records_nil then
        value = opts.records_nil(records)
    elseif not is_records_nil and opts.records_filter then
        value = opts.records_filter(records)
    else
        value = records
    end
    
    return value
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M