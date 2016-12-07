-- 自定义函数指针
local require = require
local setmetatable = setmetatable

-- 统一引用导入LIBS
local c_json = require("cjson.safe")

local _M = { _VERSION = '0.01' }

------------------------------------------ 通用配置信息，使它分离出多个区域 -----------------------------------  

--[[
---> 构造函数，缓存选区
--]]
function _M:new(conf)
    return setmetatable({ 
    		['nginx'] = function()
    			return require("app.store.cache.nginx")(conf)
    		end,
    		['redis'] = function()
    			return require("app.store.cache.redis")(conf)
    		end
    	}, { __index = _M })
end

-----------------------------------------------------------------------------------------------------------------


------------------------------------------------ 特定 缓存设置 --------------------------------------------------

--[[
---> 缓存操作指针，默认为redis
--]]

-----------------------------------------------------------------------------------------------------------------

return _M