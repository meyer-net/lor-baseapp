-- 
--[[
---> 
--------------------------------------------------------------------------
---> 参考文献如下
-----> 
--------------------------------------------------------------------------
---> Examples：
----->  local orm = store.db["default"] or store.db[""]
        -- local orm = require('app.store.orm.adapter')({
        --         driver = 'mysql', -- or 'postgresql'
        --         port = 8066,
        --         host = '127.0.0.1',
        --         user = 'root',
        --         password = '123456',
        --         database = 'gateway',
        --         charset = 'utf8mb4',
        --         expires = 100,  -- cache expires time
        --         debug = true -- log sql with ngx.log 
        --     }):open()
    
        -- local sql = orm.create_query():from('[dashboard_user]'):where('[id] = ?d', 1):one()
        -- NOTICE: 
        --      the table must have an auto increment column as its primary key
        --      define_model accept table name as paramater and cache table fields in lrucache.
        -- expr(expression, ...)
        --      ?t table {1,2,'a'} => 1,2,'a'
        --      ?b bool(0, 1), only false or nil will be converted to 0 for mysql, TRUE | FALSE in postgresql
        --      ?e expression: MAX(id) | MIN(id) ...
        --      ?d digit number, convert by tonumber
        --      ?n NULL, false and nil wil be converted to 'NULL', orther 'NOT NULL'
        --      ?s string, escaped by ngx.quote_sql_str
        --      ? any, convert by guessing the value type
        -- METHODS:
        --      Model.new([attributes]) create new instance
        --      Model.query() same as orm.create_query():from(Model.table_name())
        --      Model.find() same as query(), but return Model instance
        --      Model.find_one(cond, ...) find one record by condition
        --      Model.find_all(cond, ...) find all records by condition
        --      Model.update_where(attributes, cond, ...) update records filter by condition
        --      Model.delete_where(cond, ...) delete records filter by condition
        --      
        --      model:save() save the record, if pk is not nil then update() will be called, otherwise insert() will be called
        --      
        --      model:load(attributes) load attributes to instance
        --      model:set_dirty(attribute) make attribute dirty ( will be updated to database )
        --      model:is_new() return if this instance is new or load from database
    
        local m_usr = orm.define_model('[dashboard_user]')
    
        -- create new 
        local attrs = { 
            username = 'new user',
            password = require("app.lib.uuid")(),
            is_admin = 0,
            enable = 1
        }
    
        local i_usr = m_usr.new(attrs)
        local ok, id = i_usr:save()
    
        local model_find_one_success, model_find_one = m_usr.find_one('id = ?d', id)
    
        -- UPDATE tbl_user SET name='name updated' WHERE id > 10
        local attrs = { username = 'name updated' }
        m_usr.update_where(attrs, 'id = ?d', id)
    
        local model_find_success, model_find = m_usr.find():where('id = ?d', id):limit(1)()
    
        -- DELETE FROM tbl_user WHERE id = 10
        m_usr.delete_where('id = ?d', id) --delete all by condition
        i_usr:delete()  -- delete user instance
    
        local model_find_all_success, model_find_all = m_usr.find_all('id > ?d', 0)
    
        -- orm.transaction(function(conn)
        --     m_usr.new{ username = 'mow' }:save()
        --     -- conn:commit()
        --     conn:rollback()
        -- end)
    
        res:json({
            success = model_find_one_success and model_find_success and model_find_all_success,
            data = {
                model_find_one = model_find_one,
                model_find = model_find,
                model_find_all = model_find_all,
                --model_query = m_usr:query()
            }
        })
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require
local assert = assert
local pcall = pcall
local tostring = tostring
local coroutine = coroutine

local s_format = string.format

local n_ctx = ngx.ctx
local n_log = ngx.log
local n_err = ngx.ERR
local n_debug = ngx.DEBUG
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local l_object = require("app.lib.classic")

-----> 引擎引用
local o_query = require("app.store.orm.query")
local o_model = require("app.store.orm.model")

-----> 外部引用
-- local c_json = require("cjson.safe")
--------------------------------------------------------------------------

--[[
---> 局部变量声明
--]]
--------------------------------------------------------------------------

local namespace = "app.store.orm.adapter"

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _adapter = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 adapter.super.new(self, store, self._name)
--]]
function _adapter:new(conf)
    -- 指定名称
    self._name = conf.name or namespace

    -- 用于操作具体驱动的配置文件
    self.conf = conf

    -- 
    _adapter.super.new(self, self._name)
end

function _adapter:open()
    local conf = self.conf
    local driver = conf.driver
    assert(driver, s_format("[%s.open]Please specific db driver", namespace))

    local driver_path = "app.store.drivers."..driver
    local ok, db = pcall(require, driver_path)
    assert(ok, s_format("[%s.open]No driver for %s, %s", namespace, driver_path, db or " there's none internal error"))

    local conn = db(conf)

    local create_query = function() 
        return o_query.create(conn) 
    end

    local define_model = function(table_name) 
        return o_model(conn, create_query, table_name, conf.database) 
    end

    local transaction = function(fn)
        local in_trans, db = conn.connect()
        if in_trans then 
            return error(s_format("[%s.open.transaction]Transaction can't be nested", namespace)) 
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
<<<<<<< HEAD
        name         = self._name;
=======
>>>>>>> 77203e6a4e70d5bc9d619b7bf50f8e25884c5b97
        db           = conn;
        transaction  = transaction;
        create_query = create_query;
        define_model = define_model;
        expr         = o_query.expr(conn);
    }
end

-----------------------------------------------------------------------------------------------------------------

return _adapter
