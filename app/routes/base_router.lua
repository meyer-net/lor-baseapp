
-- 
--[[
---> 路由对外基础类
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
local type = type
local pairs = pairs
local xpcall = xpcall

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

local s_lower = string.lower
local s_format = string.format

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local lor = require("lor.index")
local l_object = require("app.lib.classic")
local common_api = require("app.plugins.common_api")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local model = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 model.super.new(self, store, self._name)
--]]
function model:new(conf, store, name)
    self._name = name

    -- 用于操作缓存与DB的对象
    self._conf = conf
    self._store = store
    self._cache = self._store.cache.using
end

-----------------------------------------------------------------------------------------------------------------

---> 加载其他"可用"插件API
local function load_plugin_api(conf, store, plugin, router)
    local plugin_api_namespace = s_format("app.plugins.%s.api", plugin)
    
    local ok, plugin_api, ex
    ok = xpcall(function() 
        plugin_api = require(plugin_api_namespace)
    end, function()
        ex = debug.traceback()
    end)

    if not ok or not plugin_api or type(plugin_api) ~= "table" then
        n_log(n_err, s_format("plugin's api of '%s' load error, %s -> ", plugin_api_namespace, ex))
        return
    end

    local common_apis = common_api(conf, store, plugin)
    local current_api = plugin_api(plugin)
    current_api:merge_apis(common_apis)
    
    local plugin_apis = current_api:get_apis()
    for uri, api_methods in pairs(plugin_apis) do
        n_log(n_debug, "load route, uri:", uri)

        if type(api_methods) == "table" then
            for method, func in pairs(api_methods) do
                method = s_lower(method)
                router[method](router, uri, func())
            end
        end
    end
end

function model:load_router(router_func)
    local router = lor:Router()

    if router_func and type(router_func) == "function" then
        router_func(router, self._conf, self._store, self._cache)
    end

    local available_plugins = self._conf.plugins
    if not available_plugins or type(available_plugins) ~= "table" or #available_plugins<1 then
        n_log(n_err, "no available plugins, maybe you should check `sys.conf`.")
    else
        for _, plugin in ipairs(available_plugins) do
            load_plugin_api(self._conf, self._store, plugin, router)
        end
    end

    return router
end

-----------------------------------------------------------------------------------------------------------------

return model
