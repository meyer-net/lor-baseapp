local tonumber = tonumber
local type = type
local pairs = pairs
local setmetatable = setmetatable

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO

local s_upper = string.upper
local s_lower = string.lower
local s_format = string.format

local _METHODS = {
    GET = true,
    POST = true,
    PUT = true,
    DELETE = true,
    PATCH = true
}

local BaseAPI = {}

function BaseAPI:new(name)
    local instance = {}
    instance._name = name
    instance._apis = {}

    setmetatable(instance, { __index = self })
    instance:build_method()
    return instance
end

function BaseAPI:get_name()
    return self._name
end

function BaseAPI:get_apis()
    return self._apis
end

function BaseAPI:set_api(path, method, func)
    if not path or not method or not func then
        return n_log(n_err, "params should not be nil.")
    end

    if type(path) ~= "string" or type(method) ~= "string" or type(func) ~= "function" then
        return n_log(n_err, "params type error")
    end 

    method = s_upper(method)
    if not _METHODS[method] then 
        return n_log(n_err, s_format("[%s] method is not supported yet.", method))
    end
    
    self._apis[path] = self._apis[path] or {}
    self._apis[path][method] = func
end

function BaseAPI:build_method()
    for m, _ in pairs(_METHODS) do
        m = s_lower(m)
        n_log(n_info, "attach method " .. m .. " to BaseAPI")
        BaseAPI[m] = function(myself, path, func)
            BaseAPI.set_api(myself, path, m, func)
        end
    end
end

function BaseAPI:merge_apis(apis)
    if apis and type(apis) == "table" then
        for path, methods in pairs(apis) do
            if methods and type(methods) == "table" then
                for m, func in pairs(methods) do
                    m = s_lower(m)
                    n_log(n_info, "merge method, path: ", path, " method:", m)
                    self:set_api(path, m, func)
                end
            end
        end
    end
end

return BaseAPI
