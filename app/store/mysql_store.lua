-- 自定义函数指针
local type = type
local ipairs = ipairs
local tonumber = tonumber

-- 统一引用导入LIBS
local mysql_db = require("app.store.mysql_db")
local s_store = require("app.store.base_store")

-----------------------------------------------------------------------------------------------------------------

local _M = s_store:extend()

--[[
---> 初始化构造器
--]]
function _M:new(options)
    self._name = options.name or "mysql-store"
    self.store_type = "mysql"
    
    self.mysql_addr = options.connect_config.host .. ":" .. options.connect_config.port
    self.data = {}
    self.db = mysql_db:new(options)

    _M.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------

-- 内部执行器，res返回如下
-- {"insert_id":668,"server_status":2,"warning_count":0,"affected_rows":1}
function _M:exec(opts, atts)
    if not opts or opts == "" then return false end
    local param_type = type(opts)
    local res, err
    if param_type == "string" then
        res, err = self.db:query(opts)
    elseif param_type == "table" then
        res, err = self.db:query(opts.sql, opts.params or {})
    end

    if not res or err then
        ngx.log(ngx.ERR, "MySQLStore => "..atts.action_name.." error => ", err)
        return false
    end

    return res, err
end

function _M:find_all()
    return nil
end

function _M:find_page()
    return nil
end

function _M:query(opts)
    if not opts or opts == "" then return nil end
    local param_type = type(opts)
    local sql, params
    if param_type == "string" then
        sql = opts
    elseif param_type == "table" then
        sql = opts.sql
        params = opts.params
    end

    local records, err = self.db:query(sql, params)
    if err then
        ngx.log(ngx.ERR, "MySQLStore => query, error => ", err, " sql => ", sql)
        return nil
    end

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

    if value and type(value) == "table" and records_len <= 0 then
        ngx.log(ngx.WARN, "MySQLStore => query empty, sql => ", sql)
    end

    return value
end

function _M:insert(opts)
    return self:exec(opts, {
            action_name = "insert"
        })
end

function _M:delete(opts)
    return self:exec(opts, {
            action_name = "delete"
        })
end

function _M:update(opts)
    return self:exec(opts, {
            action_name = "update"
        })
end

return _M