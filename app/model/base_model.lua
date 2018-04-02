--[[
---> 统一函数指针
--]]
local _object = require "app.lib.classic"

--[[
---> 统一引用导入LIBS
--]]
local u_object = require("app.utils.object")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _model = _object:extend()

---> 对象 操作区域 ----------------------------------------------------------------------------------------------

--[[
---> 构造函数
--]]
function _model:new(conf, store, name)
    self._name = name or ("svr." .. ( self._source or "anonymity") .. ".model")
    self._conf = conf
    self._store = store
end

--[[
---> 
--]]
--function _model.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _model