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

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG
--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local m_base = require("app.model.base_model")

-----> 工具引用
local u_object = require("app.utils.object")
local u_each = require("app.utils.each")

-----> 外部引用
local c_json = require("cjson.safe")

-----> 数据仓储引用
local r_model = require("app.model.repository.model_repo")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local model = m_base:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, store, self._name)
--]]
function model:new(conf, store, name)
	-- 指定名称
    self._source = "[user]"
    self._name = ( name or self._source) .. "-svr-model"
    
    -- 传导值进入父类
    model.super.new(self, conf, store, name)
    
    -- 用于操作缓存与DB的对象
    self.store = store

    -- 当前临时操作数据的仓储
    self.model = {
    	current_repo = r_model(conf, store, self._source),
    	ref_repo = {

    	}
	}

    -- 锁对象
    -- self.locker = u_locker(self.store.cache.nginx["sys_locker"], "lock-tag-name")

	-- 位于在缓存中维护的KEY值
    self.cache_prefix = s_format("%s.app<%s> => ", conf.project_name, self._name)
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 注册一个...
--]]
-- function model:regist_(params)
--     local attrs = {
--             enable = params.enable
--         }
-- 
--     return self.model.current_repo:save(attrs)
-- end

--[[
---> 删除一个...
--]]
-- function model:remove_(params)
--     local attrs = {
--             id = params.id
--         }
-- 
--     return self.model.current_repo:delete(attrs)
-- end

--[[
---> 刷新一个...信息
--]]
-- function model:refresh_(params)
--     local attrs = {
--             id = params.id,
--             enable = params.enable
--         }
-- 
--     return self.model.current_repo:update(attrs)
-- end

--[[
---> 查询单个...
--]]
-- function model:get_(id)
--     -- 查询缓存或数据库中是否包含指定信息
--     local cache_key = s_format("%s%s -> %s", self.cache_prefix, self._source, id)
--     local timeout = 0
--     
--     return self.store.cache.using:get_or_load(cache_key, function() 
--         return self.model.current_repo:find_one({
--                 id = id
--             })
--     end, timeout)
-- end

--[[
---> 
--]]
--function model:query_(...)
--	-- 查询缓存或数据库中是否包含指定信息
--	local cache_key = s_format("%s%s-%s", self.cache_prefix, self._source, "all")
--  	local timeout = 0
--	
--  	return self.store.cache.using:get_or_load(cache_key, function() 
--  		return self.model.current_repo:find_all({
--  		
--          })
--  	end, timeout)
--end

-----------------------------------------------------------------------------------------------------------------

return model