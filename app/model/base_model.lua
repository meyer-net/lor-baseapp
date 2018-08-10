--[[
---> 统一函数指针
--]]
local require = require

--[[
---> 统一引用导入LIBS
--]]
local u_base = require("app.utils.base")
local u_object = require("app.utils.object")
local u_locker = require("app.utils.locker")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _model = u_base:extend()

---> 对象 操作区域 ----------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, conf, store, name)
--]]
function _model:new(conf, store, name, opts)
    name = name or ( self._source or "anonymity" ) .. ".model"

	-- 传导至父类填充基类操作对象
    _model.super.new(self, name, opts)
    
    -- 配置器
    self._conf = conf

    -- 仓储器
    self._store = store

    -- 缓存
    self._cache = self._store.cache.using

    -- 锁对象
    self._locker = u_locker(self._store.cache.nginx["sys_locker"], self._name)
    
    -- 当前临时操作数据的仓储
    self._model = {
    	-- current_repo = r_buffer(conf, store),
        -- log = s_log(conf, store),
    	ref_repo = {

    	}
	}
end

--[[
---> 
--]]
--function _model.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _model