
-- 
--[[
---> 插件API对外基础类
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
--------------------------------------------------------------------------
---> Examples：
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber
local type = type
local pairs = pairs
local setmetatable = setmetatable

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

local s_upper = string.upper
local s_lower = string.lower
local s_format = string.format

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local m_base = require("app.model.base_model")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local api = m_base:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 api.super.new(self, self._name)
--]]
function api:new(conf, store, name)
    self._name = s_format("[%s]-api", name)
    
    -- 传导值进入父类
    api.super.new(self, conf, store, name)

    self._apis = {}
	self._plugin = name
    self:build_method()
end

-----------------------------------------------------------------------------------------------------------------

local _METHODS = {
    GET = true,
    POST = true,
    PUT = true,
    DELETE = true,
    PATCH = true
}

function api:get_name()
    return self._name
end

function api:get_apis()
    return self._apis
end

function api:set_api(uri, method, func)
    if not uri or not method or not func then
        return n_log(n_err, "params should not be nil.")
    end

    if type(uri) ~= "string" or type(method) ~= "string" or type(func) ~= "function" then
        return n_log(n_err, "params type error")
    end 

    method = s_upper(method)
    if not _METHODS[method] then 
        return n_log(n_err, s_format("[%s] method is not supported yet", method))
    end
    
    self._apis[uri] = self._apis[uri] or {}
    self._apis[uri][method] = func
end

function api:build_method()
    for method, _ in pairs(_METHODS) do
        method = s_lower(method)
        n_log(n_debug, "attach method " .. method .. " to api")
        api[method] = function(self, uri, func)
            api.set_api(self, uri, method, func)
        end
    end
end

function api:merge_apis(apis)
    if apis and type(apis) == "table" then
        for uri, methods in pairs(apis) do
            if methods and type(methods) == "table" then
                for method, func in pairs(methods) do
                    method = s_lower(method)
                    n_log(n_debug, "merge method, uri: ", uri, " method:", method)
                    self:set_api(uri, method, func)
                end
            end
        end
    end
end

-----------------------------------------------------------------------------------------------------------------

return api
