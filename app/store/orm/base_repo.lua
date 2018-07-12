-- 
--[[
---> 用于落地操作来自于（XXX）的数据
---> 该类作为实现增删改查的基类
--------------------------------------------------------------------------
---> 参考文献如下
-----> /根路径/app/model/service/xxx_svr.lua
-----> /根路径/app/model/repository/xxx_repo.lua
--------------------------------------------------------------------------
---> Examples：
-----> local r_model_module = require("app.model.repository.model_module")
-----> local tbl_model_module = r_model_module(store)

-----> local success = tbl_model_module:save({
-----> 		shunt = "b.test-x => utmcmd.test", 
-----> 		source = "b.test-x", 
-----> 		medium = "utmcmd.test", 
-----> 		data = "{ }"
-----> 	})
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require
local s_format = string.format
local s_upper = string.upper
local s_reverse = string.reverse
local s_gsub = string.gsub

local t_insert = table.insert
local t_unpack = table.unpack
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local u_base = require("app.utils.base")

-----> 工具引用
--

--------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local model = u_base:extend()
-----------------------------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, self._name, orm_driver)
--]]
function model:new(conf, store, source, conf_db_node)
	-- 指定名称
	assert(source, s_format("Can't assign the source '%s' which repo used it", source))
	self._source = source or "[anymouse]"
	
	local name = s_format("%s-repo-model", self._source)
	
	model.super.new(self, name)
    
	-- 用于操作落地的DB节点对象
	assert(conf_db_node, s_format("Can't assign the db conf node '%s' which repo of '%s' used it", conf_db_node or "unknow", source))
	self._orm_driver = store.db[conf_db_node] or store.db[""]
	
    -- 用于连接数据的节点
    self._adapter = {
    	current_model = (self._orm_driver).define_model(self._source)
    }
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 获取占位符，用于内容参数化操作，谨防SQL注入
--]]
function model:get_perch(obj)
	-- 作为URL参数传递进来的数值类型，必定是string类型的
	local string_obj = tostring(obj)
	local match, err = ngx.re.match(string_obj, "^[0-9]+$")

	if match then
		return "?d"
	end

	local v_type = type(obj)

	local switch = {
		["string"] = function ()
			return "?s"
		end,
		["boolean"] = function ()
			return "?b"
		end,
		["table"] = function ()
			return "?t"
		end
	}

	local choice = switch[v_type]

	-- 没有类型的情况下
	if not choice then 		
		return "?"
	end

	-- 为空的情况下
	local upper_obj = s_upper(string_obj)
	if upper_obj == "NULL" then
		return "?n"
	end

	-- 为表达式的情况下
	if (self.utils.string.starts_with(upper_obj, "MAX%(") or
	    self.utils.string.starts_with(upper_obj, "MIN%(")) then
	   	local reverse_obj = s_reverse(upper_obj)
	   	if self.utils.string.starts_with(reverse_obj, "%)") then
	   		return "?e"
	   	end
	end

	return switch[v_type]()
end

--[[
---> 有指定需查寻的字段时
--]]
function model:get_cond(cond, orders, slt)
	local _cond = {
		cond = cond
	}

	if self.utils.object.check(orders) then
		_cond.orders = orders
	end

	if self.utils.object.check(slt) then
		_cond.fields = slt.fields
		_cond.values = slt.values
	end

	return _cond
end

--[[
---> 分解参数为ORM所需要的格式
----> attrs 用来绑定的条件键值对
----> slt 用来查询的字段数据
--]]
function model:resolve_attr(attrs, slt)
	local cond = ""
	local orders = ""
	local params = {}

	self.utils.each.json_action(attrs, function ( key, value )
		local opr = '='
		local cvrt = true  -- 是否对值进行转换
		if type(key) == "number" and type(value) == "table" then
			local values = value
			key,value,opr,cvrt = values[1],values[2],values[3] or opr,values[4]
		end

		local new_key = s_gsub(tostring(key), "order_by_", "")
		if (new_key == key) then
			local perch = value

			if cvrt then
				perch = self:get_perch(value)
			end
			
			if cond == "" then 
				cond = s_format("%s %s %s", key, opr, perch)
			else
				cond = s_format("%s and %s %s %s", cond, key, opr, perch)
			end

			if cvrt then
				t_insert(params, value)
			end
		else
			if orders == "" then 
				orders = s_format("%s %s", new_key, value)
			else
				orders = s_format("%s, %s %s", orders, new_key, value)
			end
		end
	end)

	return self:get_cond(cond, orders, slt), params
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 保存一条记录，并返回ok, id，auto_model 为是否启用含主键自动变为更新机制
--]]
function model:save(mdl, auto_model)
	return self._adapter.current_model.new(mdl):save(auto_model)
end

--[[
---> 按id删除一条记录，并返回ok，effects
--]]
function model:delete(attr)
	local cond, params = self:resolve_attr(attr)
	return self._adapter.current_model.delete_where(cond, t_unpack(params))
end

--[[
---> 按id更新一条记录，并返回ok，effects
--]]
function model:update(mdl, attr)
	local cond, params = self:resolve_attr(attr)
	return self._adapter.current_model.update_where(mdl, cond, t_unpack(params))
end

--[[
---> 按id查询一条记录，并返回ok，指定记录
--]]
function model:find_one(attr)
	local cond, params = self:resolve_attr(attr)
	return self._adapter.current_model.find_one(cond, t_unpack(params))
end

--[[
---> 按指定条件查询记录，并返回ok，records
--]]
function model:find_all(attr, slt)
	local cond, params = self:resolve_attr(attr, slt)
	return self._adapter.current_model.find_all(cond, t_unpack(params))
end

--[[
---> 按指定条件查询哈希记录，并返回ok，records
--]]
function model:find_hash_all(key, attr)
	local cond, params = self:resolve_attr(attr)
    local ok, records  = self._adapter.current_model.find_all(cond, params)

    return ok, u_db.filter_records({
    		records_filter = function (records)
                    local hash_records = {}
                    self.utils.each.array_action(records, function (_, item)
                        local tmp_key = tostring(item[key])
                        item[key] = nil
                        hash_records[tmp_key] = item
                    end)
                    return hash_records
                end
    	})
end

-----------------------------------------------------------------------------------------------------------------

return model