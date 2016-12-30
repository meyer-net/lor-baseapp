local assert = assert
local pcall = pcall

local n_ctx = ngx.ctx

local o_query = require 'orm.query'
local o_model = require 'orm.model'

local function open(conf)
    local driver = conf.driver
    assert(driver, "please specific db driver")

    local ok, db = pcall(require, 'orm.drivers.' .. driver)
    assert(ok, 'no driver for ' .. driver)

    local conn = db(conf)

    local create_query = function() 
        return o_query.create(conn) 
    end

    local define_model = function(table_name) 
        return o_model(conn, create_query, table_name) 
    end

    local transaction = function(fn)
        local in_trans, db = conn.connect()
        if in_trans then 
            return error("transaction can't be nested") 
        end

        local ok, err = db:start_transaction()
        assert(ok, err)

        local thread = coroutine.create(fn)
        local key = "trans_" .. tostring(thread)

        n_ctx[key] = db

        local status, res
        while coroutine.status(thread) ~= 'dead' do
            status, res = coroutine.resume(thread, db)
        end

        db:set_keepalive(10000, 50)
        n_ctx[key] = nil

        return status, res
    end

    return {
        db           = conn;
        transaction  = transaction;
        create_query = create_query;
        define_model = define_model;
        expr         = o_query.expr(conn);
    }
end

return {
    open = open;
}
