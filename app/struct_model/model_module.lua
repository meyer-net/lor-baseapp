-- 
--[[
---> 
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
local require = require
local s_format = string.format
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local object = require("app.lib.classic")

-----> 工具引用
local u_object = require("app.utils.object")
local u_each = require("app.utils.each")

-----> 外部引用
local c_json = require("cjson.safe")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local model = object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, store, self._name)
--]]
function model:new(store, name)
	-- 指定名称
    self._name = name or "anonymity model"
    
    -- 用于操作缓存与DB的对象
    self.store = store

	-- 位于在缓存中维护的KEY值
    self.cache_prefix = ""
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 
--]]
--function model:query_(...)
--	-- 查询缓存或数据库中是否包含指定信息
--	local cache_key = s_format("%s%s", self.cache_prefix, ...)
--  	local timeout = 0
--	local query_text = ""
--	local query_params = { ... }
--	
--  	return self.store.cache.using:get_or_load(cache_key, function() {
--  		return self.store.db:query({
--                sql = query_text,
--                params = query_params,
--  			  	records_filter = function (records)
--  			  			return records[1]
--  			  	end
--            })
--  	}, timeout)
--end



-----------------------------------------------------------------------------------------------------------------

return model