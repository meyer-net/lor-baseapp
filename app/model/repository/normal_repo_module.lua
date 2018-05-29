-- 
--[[
---> 用于落地存储来自于（）的数据
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
--------------------------------------------------------------------------
---> Examples：
-----> local r_model_module = require("app.model.repository.model_module")
-----> local tbl_model_module = r_model_module(store)

-----> local success = tbl_model_module:append({
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
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local l_object = require("app.lib.classic")

-----> 工具引用
--local u_object = require("app.utils.object")
--local u_each = require("app.utils.each")

-----> 外部引用
--local c_json = require("cjson.safe")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local model = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, store, self._name)
--]]
function model:new(config, store, name)
	-- 指定名称
    self._name = (name or "anonymity") .. "-repository-model"
    
    -- 用于操作缓存与DB的对象
    self._store = store

    -- 用于连接数据的节点
    self._adapter = {
      current_db = self._store.db["default"] or self._store.db[""]
    }
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 追加一条记录
--]]
-- function model:append(params)
-- 	local command_text = "INSERT INTO `model_module` (`gid`, `create_date`) VALUES (?, ?)"
-- 	local command_params = {  }

-- 	return self._adapter.current_db.insert({
--                 sql = command_text,
--                 params = command_params
--             })
-- end

---> 更新一条记录
--]]
-- function model:update(params)
-- 	local command_text = "UPDATE `model_module` SET A=? WHERE id=?"
-- 	local command_params = { params.id }

-- 	return self._adapter.current_db.update({
--                 sql = command_text,
--                 params = command_params
--             })
-- end

--[[
---> 查询记录
--]]
-- function model:query_(params)
-- 	local query_text = "SELECT * FROM `model_module`"
-- 	local query_params = { }

-- 	return self._adapter.current_db.query({
--                 sql = query_text,
--                 params = query_params,
--  			  	records_filter = function (records)
--  			  		return records[1]
--  			  	end
--             })
-- end

--[[
---> 查询记录
--]]
-- function model:query_hash_(params)
--     local query_text = "SELECT * FROM `model_module`"
--     local query_params = { }
--     
--     return self._adapter.current_db.query({
--                 sql = query_text,
--                 params = query_params,
--                 records_filter = function (records)
--                     local hash_records = {}
--                     u_each.array_action(records, function (_, item)
--                         local tmp_key = tostring(item[params.key])
--                         item[params.key] = nil
--                         hash_records[tmp_key] = item
--                     end)
--                     return hash_records
--                 end
--             })
-- end

-----------------------------------------------------------------------------------------------------------------

return model