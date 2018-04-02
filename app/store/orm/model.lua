local setmetatable = setmetatable
local rawget = rawget
local assert = assert
local type = type

local s_format = string.format

local o_func = require 'app.store.orm.func'
local o_cache = require 'app.store.orm.cache'
local t_concat = table.concat

local namespace = "app.store.orm.model"

local function define_model(DB, Query, table_name)
    local _M = {  }
    local _relations = {  }

    assert(type(table_name) == 'string', s_format("[%s.define_model]Table name required", namespace))

    _M.table_name = function() 
        return table_name:gsub('%[?([^%]]+)%]?', '%1')
    end

    -- User.has_one{ model = 'models.profile', as = 'profile', link = { 'user_id', 'id'} }
    _M.has_one = function(conf)
        _relations[conf.as] = conf
    end

    _M.has_many = _M.has_one

    local _init_model = function(Model)

        local attrs 

        local conf = DB.config()
        local cache_key = t_concat({'orm', conf.host, conf.port, conf.database, table_name}, '^') 
        local data, stale = o_cache:get(cache_key)

        if not data then
            attrs = DB.get_schema(table_name)
            o_cache:set(cache_key, o_func.table_clone(attrs), conf.expires)
        else
            attrs = o_func.table_clone(data)
        end

        assert(attrs, s_format("[%s.define_model._init_model]Initializing model failed", namespace))
        assert(attrs.__pk__, s_format("[%s.define_model._init_model]Primary key required", namespace))
        local pk = attrs.__pk__
        attrs.__pk__ = nil

        local function quote_key(val) 
            local typ = type(val)
            if typ == 'string' then
                return '['.. val .. ']'
            elseif typ == 'table' then
                return o_func.kmap(function(k, v)
                    return '[' .. k .. ']', v
                end, val)
            end

            return error(s_format("[%s.quote_key]Can not quote keys", namespace))
        end

        local function filter_attrs(params)
            return o_func.kmap(function(k, v)
                if type(k) == 'number' then
                    return k, v
                elseif attrs[k] ~= nil then
                    return k, v
                end
            end, params)
        end

        local function pop_models(ok, rows)
            if not ok then return ok, rows end

            return ok, o_func.map(function(row)
                local model = Model.new(row, true)
                model:trigger('after_find')
                return model
            end, rows)
        end

        local function query()
            return Query():from(table_name)
        end

        Model.query = query

        Model.primary_key = function()
            return pk
        end

        Model.find = function(with)
            local q = query()
            getmetatable(q).__call = function(self)
                if self._state == 'select' then
                    return pop_models(self:exec())
                end
                return self:exec()
            end

            return q
        end

        -- if with then
        --     with = type(with) == 'string' and { with } or with
        --     for _, w in with do
        --         local rel = _relations[w]
        --         if not rel then
        --             error('relation '..w..' not found')
        --         end
        --         self:left_join(require(conf.model).table_name(), )
        --     end
        -- end

        Model.group = function(expr, cond, ...)
            local q = query():select(expr .. ' AS group__res')
            if cond then q:where(cond.cond, ...) end

            local ok, res = q()
            if ok and #res > 0 then
                return res[1].group__res
            end
            return nil
        end

        Model.count = function(cond, ...)
            return Model.group('COUNT(*)', cond, ...)
        end

        -- 附加函数，用于处理where的问题
        local bind_find = function ( cond, ... )
            local _find = Model.find()
            if cond.fields and cond.values then
                _find = _find.select(cond.fields, table.unpack(cond.values))
            end

            _find = _find:where(cond.cond, ...)
            if cond.orders then
                _find = _find:order_by(cond.orders)
            end

            return _find
        end

        Model.find_all = function(cond, ...)
            local _find = bind_find(cond, ...)
            return _find()
        end

        Model.find_one = function(cond, ...)
            local _find = bind_find(cond, ...)

            local ok, records = _find:limit(1)()
            if ok then 
                records = records[1]
            end

            return ok, records
        end

        Model.update_where = function(set, cond, ...)
            return query():update():where(cond.cond, ...):set(set)()
        end

        Model.delete_where = function(cond, ...)
            return query():delete():where(cond.cond, ...)()
        end

        Model.__index = function(self, key)
            if Model[key] then
                return Model[key]
            else
                return self.__attrs__[key]
            end
        end

        Model.__newindex = function(self, k, v)
            if attrs[k] ~= nil then
                self.__attrs__[k] = v
                self.__dirty_attrs__[k] = true
            else
                rawset(self, k, v)
            end
        end
        
        function Model:get_data()
            return self.__attrs__
        end

        function Model:set_dirty(attr)
            self.__dirty_attrs__[attr] = true
        end

        function Model:get_dirty_attrs()
            local count = 0
            local res = o_func.kmap(function(k, v)
                count = count + 1
                return k, self.__attrs__[k] 
            end, self.__dirty_attrs__)
            return res, count
        end

        function Model:save(auto_mode)
            if not self:trigger('before_save') then
                return false, 'error on before save'
            end

            if auto_mode == nil then
                auto_mode = true
            end

            if auto_mode and self[pk] then -- update
                local res = "no dirty attributes"
                local ok = false
                local dirty_attrs, count = self:get_dirty_attrs()
                if count > 0 then
                    ok, res = query():update():where(quote_key(pk) .. ' = ?d ', self[pk]):set(quote_key(dirty_attrs))()

                    if ok then
                        self:set_none_dirty()
                    end
                end

                return ok, res
            else -- insert
                local ok, res = query():insert():values(quote_key(self.__attrs__))
                        :returning(quote_key(pk), 'insert_id')()  -- for postgresql

                if ok and res.insert_id then 
                    self[pk] = res.insert_id
                    self:set_none_dirty()
                    self.__is_new__ = false
                    return ok, res.insert_id
                else
                    return false, res
                end
            end
        end

        function Model:set_none_dirty()
            self.__dirty_attrs__ = {}
        end

        function Model:delete()
            assert(self[pk], s_format("[%s.define_model._init_model.Model:delete]Primary key ['%s'] required", namespace, pk))

            return query():delete():where(quote_key(pk) .. '= ?d', self[pk])()
        end

        function Model:load(data)
            if type(data) == 'table' then
                o_func.kmap(function(k, v) 
                    self[k] = v 
                end, data)
            end
        end

        function Model:trigger(event, ...)
            local method = Model['on_'..event]
            if type(method) == 'function' then
                return method(self, ...)
            end
            return true
        end

        function Model:is_new()
            return self.__is_new__
        end

        Model.new = function(data, from_db)
            local instance = { __attrs__ = {}, __dirty_attrs__ = {} , __is_new__ = true }
            setmetatable(instance, Model)

            instance:load(data)
            if from_db then
                instance:set_none_dirty()
                -- while loading from db, records are not new
                instance.__is_new__ = false
            end

            return instance
        end

        setmetatable(Model, nil)
    end

    return setmetatable(_M, {
        __index = function(self, key)
            _init_model(self)
            return rawget(self, key)
        end
    })
end

return define_model

