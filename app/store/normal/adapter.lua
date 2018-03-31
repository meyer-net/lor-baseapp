-- 
--[[
---> 普通基于SQL脚本形式的数据查询适配器
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
local type = type
local ipairs = ipairs
local tonumber = tonumber

local s_format = string.format

local n_log = ngx.log
local n_err = ngx.ERR
local n_warn = ngx.WARN

-- 统一引用导入LIBS
local u_db = require("app.utils.db")
local u_obj = require("app.utils.object")
local s_store = require("app.store.base_store")
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local l_object = require("app.lib.classic")

-----> 引擎引用
local o_query = require("app.store.normal.query")

-----> 外部引用
-- local c_json = require("cjson.safe")
--------------------------------------------------------------------------

--[[
---> 局部变量声明
--]]
--------------------------------------------------------------------------

local namespace = "app.store.normal.adapter"

-----------------------------------------------------------------------------------------------------------------

local _adapter = s_store:extend()

--[[
---> 初始化构造器
--]]
function _adapter:new(conf)
    -- 指定名称
    self._name = conf.name or namespace

    -- 用于操作具体驱动的配置文件
    self.conf = conf
    -- self.mysql_addr = conf.host .. ":" .. conf.port

    -- 
    _adapter.super.new(self, self._name)
end

function _adapter:open()
    local conf = self.conf
    local driver = conf.driver
    assert(driver, s_format("[%s.open]Please specific db driver", namespace))

    local driver_path = "app.store.drivers."..driver
    local ok, db = pcall(require, driver_path)
    assert(ok, s_format("[%s.open]No driver for %s", namespace, driver_path))

    local conn = db(conf)

    local command = function(sql) 
        return o_query.create(conn)(sql) 
    end

    -- 内部执行器，res返回如下
    -- {"insert_id":668,"server_status":2,"warning_count":0,"affected_rows":1}
    local get_sql = function ( opts )
        local param_type = type(opts)
        local sql
        if param_type == "string" then
            sql = opts
        elseif param_type == "table" then
            sql = u_db.parse_sql(opts.sql, opts.params or {})
        end

        return sql
    end

    local exec = function (opts, atts)
        if not u_obj.check(opts) then return false end
        local sql = get_sql(opts)

        local ok, effects = command(sql)
    
        if not ok then
            n_log(n_err, s_format("[%s.open.exec.%s][%s],%s", namespace, atts.action_name, sql, ok))
            return false
        end
        --??? 此处旧项目需要调换位置，因旧项目返回值未与ORM保持统一
        return ok, effects 
    end
    
    local query = function (opts)
        if not u_obj.check(opts) then return nil end

        local sql = get_sql(opts)
        local ok, records = command(sql)
        if not ok then
            n_log(n_err, s_format("[%s.open.query][%s],%s", namespace, sql, ok))
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
            n_log(n_warn, s_format("[%s.open.query_empty]%s", namespace, sql))
        end
    
        return value
    end
    
    local insert = function (opts)
        return exec(opts, {
                action_name = "insert"
            })
    end
    
    local delete = function (opts)
        return exec(opts, {
                action_name = "delete"
            })
    end
    
    local update = function (opts)
        return exec(opts, {
                action_name = "update"
            })
    end

    return {
        exec          =  exec;
        find_all      =  find_all;
        find_page     =  find_page;
        query         =  query;
        insert        =  insert;
        delete        =  delete;
        update        =  update;
    }
end

-----------------------------------------------------------------------------------------------------------------

return _adapter