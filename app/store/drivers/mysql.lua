local require = require
local assert = assert
local ipairs = ipairs
local tostring = tostring
local coroutine = coroutine

local s_format = string.format

local t_concat = table.concat
local t_insert = table.insert

local n_log = ngx.log
local n_err = ngx.ERR
local n_debug = ngx.DEBUG
local quote_sql_str = ngx.quote_sql_str

-----> 外部引用
-- local c_json = require("cjson.safe")
local lpeg = require 'lpeg'
local r_mysql = require 'resty.mysql'
local o_func = require 'app.store.orm.func'

local namespace = "app.store.drivers.mysql"

local open = function(conf)
    local _connect = function()
        local db, err = r_mysql:new()
        assert(not err, s_format("[%s.open._connect]Failed to create：%s", namespace, err))

        local ok, err, errno, sqlstate = db:connect(conf)
        assert(ok, s_format("[%s.open._connect]Failed to connect：%s,%s,%s", namespace, err, errno, sqlstate))

        if conf.charset then
            if db:get_reused_times() == 0 then
                db:query("SET NAMES " .. conf.charset)
            end
        end

        return  {
            conn = db;
            query = function(self, str) return db:query(str) end;
            set_timeout = function(self, ...) return db:set_timeout(...) end;
            set_keepalive = function(self, ...) return db:set_keepalive(...) end;
            start_transaction = function() return db:query('BEGIN') end;
            commit = function() return db:query('COMMIT') end;
            rollback = function() return db:query('ROLLBACK') end;
        }
    end

    local function connect()
        local key = "trans_" .. tostring(coroutine.running())
        local conn = ngx.ctx[key]
        if conn then
            return true, conn
        end

        return false, _connect()
    end

    local config = function()
        return conf
    end

    local query = function(query_str)
        if conf.debug then
            n_log(n_debug, s_format("[%s.open.query]SQL：%s", namespace, query_str))
        end
        
        local is_trans, db = connect()
        db:set_timeout(conf.timeout) -- 1 sec
        
        local res, err, errno, sqlstate = db:query(query_str)
        if not res then
            err = s_format("[%s.open.query]Bad result: %s,%s,%s", namespace, err, errno, sqlstate)
            n_log(n_err, err)
            return false, err
        end

        if err == 'again' then res = { res } end
        while err == "again" do
            local tmp
            tmp, err, errno, sqlstate = db.conn:read_result()
            if not tmp then
                err = s_format("[%s.open.query.again]Bad result: %s,%s,%s", namespace, err, errno, sqlstate)
                n_log(n_err, err)
                return false, err
            end

            t_insert(res, tmp)
        end

        if not is_trans then
            local ok, err = db.conn:set_keepalive(conf.pool_set.max_idle_timeout, conf.pool_set.pool_size)
            if not ok then
                n_log(n_err, s_format("[%s.open.query]Failed to set keepalive：%s", namespace, err))
            end
        end

        return true, res
    end

    local escape_identifier = function(id)
        local repl = '`%1`'
        local openp, endp = lpeg.P'[', lpeg.P']'
        local quote_pat = openp * lpeg.C(( 1 - endp)^1) * endp
        return lpeg.Cs((quote_pat/repl + 1)^0):match(id)
    end

    local function escape_literal(val)
        local typ = type(val)

        if typ == 'boolean' then
            return val and 1 or 0
        elseif typ == 'string' then
            return quote_sql_str(val)
        elseif typ == 'number' then
            return val
        elseif typ == 'nil' then
            return "NULL"
        elseif typ == 'table' then
            if val._type then 
                return tostring(val) 
            end
            return t_concat(o_func.map(escape_literal, val), ', ')
        else
            return tostring(val)
        end
    end

    local returning = function(column)
        return nil
        -- return column
    end

    local get_schema = function(table_name)

        table_name = table_name:gsub('%[?([^%]]+)%]?', "'%1'")

        local ok, res = query([[
            SELECT column_name, data_type, column_key, character_maximum_length 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE table_name = ]] 
            .. table_name 
            .. ' GROUP BY column_name ')  --' AND table_schema = ' .. escape_literal(conf.database)

        assert(ok, res)

        local fields = {  }
        for _, f in ipairs(res) do
            fields[f.column_name] = f
            -- MYCAT 分区会有多个主键产生，这里暂时先取消判断，改成以ID命名设置的主键为主
            -- if f.column_key == 'PRI' then
            --     if fields.__pk__ then
            --         error(s_format("[%s.open.get_schema]Not implement for tables have multiple pk", namespace))
            --     end
            --     fields.__pk__ = f.column_name
            -- end
            if f.column_key == 'PRI' and string.lower(f.column_name) == "id" then
                fields.__pk__ = f.column_name
            end
        end

        return fields
    end

    local limit_all = function()
        return  '18446744073709551615'
    end

    return { 
        connect = connect;
        query = query;
        get_schema = get_schema;
        config = config;
        escape_identifier = escape_identifier;
        escape_literal = escape_literal;
        quote_sql_str = quote_sql_str;
        returning = returning;
        limit_all = limit_all;
    }
end

return open
