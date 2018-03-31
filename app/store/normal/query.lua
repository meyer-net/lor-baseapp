-- 
--[[
---> 普通基于SQL脚本形式的数据查询器
--------------------------------------------------------------------------
---> 参考文献如下
-----> 
--------------------------------------------------------------------------
---> Examples：
-----> 
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
-- 自定义函数指针
local error = error
local setmetatable = setmetatable

local s_format = string.format

--------------------------------------------------------------------------

--[[
---> 局部变量声明
--]]
local namespace = "app.store.normal.query"

-----------------------------------------------------------------------------------------------------------------

local _T = {}  

_T.exec = function(self, sql)
    return self._db.query(sql)
end

local function create_query(db)
    local query = {
        _db         = db,
        _state      = 'select',
        _type       = 'query'
    }

    query.quote_sql_str     = db.quote_sql_str
    query.escape_literal    = db.escape_literal
    query.escape_identifier = db.escape_identifier
    query.limit_all         = db.limit_all

    local mt = {
        __index = _T,
        __newindex = function(tbl, key, val)
            error(s_format("[%s.create_query.mt]No new value allowed", namespace))
        end,
        __tostring = function(self)
            return namespace
        end,
        __call = function(self, ...)
            return self:exec(...)
        end
    }

    return setmetatable(query, mt)
end

return { 
    create = create_query
}