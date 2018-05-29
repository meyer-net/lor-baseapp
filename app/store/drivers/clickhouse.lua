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
local c_json = require("cjson.safe")
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")
local lpeg = require 'lpeg'
local r_http = require 'resty.http'
local o_func = require 'app.store.orm.func'

local namespace = "app.store.drivers.clickhouse"

local open = function(conf)
    local _connect = function()
        local http, err = r_http.new()
        assert(not err, s_format("[%s.open._connect]Failed to create：%s", namespace, err))

        local ok, err = http:connect(conf.host or "127.0.0.1", conf.port or 8123)
        assert(ok, s_format("[%s.open._connect]Failed to connect：%s", namespace, err))

        local headers = { }
        if conf.charset then
            headers["charset"] = conf.charset
        end
        
        return  {
            conn = http;
            query = function(self, str) 
                local res, err = http:request({
                    path = "/",
                    method = "POST",
                    headers = headers,
                    body = str
                })

                local body = res:read_body()
                local get_err = function ( )
                    return u_string.match_wrape_with(body, "DB::Exception: ", ", e.what()")
                end
                
                -- if u_string.starts_with(res.status, "2") or u_string.starts_with(res.status, "3") then
                if res.has_body then
                    if not u_object.check(body) then
                        body = {
                            insert_id = 0,
                            affected_rows = 1,
                            server_status = 2,
                            warning_count = 0
                        }
                    else
                        body = c_json.decode(body)
                        if u_object.check(body) then
                            body = body.data
                        end
                    end
                else
                    err = c_json.encode({
                        status = res.status,
                        http_err = err,
                        body_err = get_err()
                    })
                end

                return body, err
            end;
            set_timeout = function(self, ...) return http:set_timeout(...) end;
            set_keepalive = function(self, ...) return http:set_keepalive(...) end;
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
        
        local res, err = db:query(query_str)
        -- [{"column_name":"content","column_key":"","character_maximum_length":"2048","data_type":"varchar"},{"column_name":"create_date","column_key":"","character_maximum_length":null,"data_type":"date"},{"column_name":"create_time","column_key":"","character_maximum_length":null,"data_type":"datetime"},{"column_name":"from","column_key":"","character_maximum_length":"256","data_type":"varchar"},{"column_name":"gid","column_key":"PRI","character_maximum_length":null,"data_type":"int"},{"column_name":"host","column_key":"","character_maximum_length":"15","data_type":"varchar"},{"column_name":"id","column_key":"PRI","character_maximum_length":"36","data_type":"varchar"},{"column_name":"level","column_key":"","character_maximum_length":null,"data_type":"int"},{"column_name":"project","column_key":"","character_maximum_length":"36","data_type":"varchar"},{"column_name":"uri","column_key":"","character_maximum_length":"100","data_type":"varchar"}]
        -- {"insert_id":0,"affected_rows":1,"server_status":2,"warning_count":0}
            
        if not res then
            err = s_format("[%s.open.query]Bad result: %s", namespace, err or res)
            n_log(n_err, err)
            return false, err
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

        local ok, res = query([[SELECT name as column_name, type as data_type FROM `system`.columns WHERE table = ]] 
            .. table_name
            .. [[ AND database = ]] 
            .. escape_literal(conf.database)
            .. [[ FORMAT JSON]])

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

        if not fields.__pk__ then
            fields.__pk__ = "id"
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
