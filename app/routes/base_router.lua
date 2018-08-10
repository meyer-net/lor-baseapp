
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
local n_alert = ngx.ALERT
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
local m_base = require("app.model.base_model")
local p_default = require("app.plugins.default_api")
local common_api = require("app.plugins.common_api")

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
    self._name = ( name or "anonymity" ) .. ".router"
    
    -- 传导值进入父类
    model.super.new(self, conf, store, name)
    
    -- 专用于插件的缓存
    self._plugin_cache = self._store.plugin
end

-----------------------------------------------------------------------------------------------------------------

---> 加载其他"可用"插件API
local function fill_plugin_api(conf, store, plugin, router)
    local plugin_api_namespace = s_format("app.plugins.%s.api", plugin)
    
    local ok, plugin_api, ex
    ok = xpcall(function() 
        plugin_api = require(plugin_api_namespace)
    end, function()
        -- 开启默认的api
        -- ex = debug.traceback()
        plugin_api = p_default
        
        n_log(n_alert, s_format("plugin's api of '%s' can not load, reset to 'default'", plugin_api_namespace))
    end)

    local current_api = plugin_api(conf, store, plugin)
    if plugin ~= "stat" then
        local common_apis = common_api(conf, store, plugin)
        current_api:merge_apis(common_apis)
    end
    
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
        router_func(router)
    end

    local available_plugins = self._conf.plugins
    if not available_plugins or type(available_plugins) ~= "table" or #available_plugins<1 then
        self._log.err("no available plugins, maybe you should check `sys.conf`.")
    else
        for _, plugin in ipairs(available_plugins) do
            fill_plugin_api(self._conf, self._store, plugin, router)
        end
    end

    return router
end

function model:load_plugins()
    local available_plugins = self._conf.plugins
    local plugins = {}
    for i, v in ipairs(available_plugins) do
        local tmp
        if v ~= "kvstore" then
            tmp = {
                enable =  self._plugin_cache:get(v .. ".enable"),
                name = v,
                active_selector_count = 0,
                inactive_selector_count = 0,
                active_rule_count = 0,
                inactive_rule_count = 0
            }
            
            local plugin_selectors = self._plugin_cache:get_json(v .. ".selectors")
            if plugin_selectors then
                for sid, s in pairs(plugin_selectors) do
                    if s.enable == true then
                        tmp.active_selector_count = tmp.active_selector_count + 1
                        local selector_rules = self._plugin_cache:get_json(v .. ".selector." .. sid .. ".rules")
                        for _, r in ipairs(selector_rules) do
                            if r.enable == true then
                                tmp.active_rule_count = tmp.active_rule_count + 1
                            else
                                tmp.inactive_rule_count = tmp.inactive_rule_count + 1
                            end
                        end
                    else
                        tmp.inactive_selector_count = tmp.inactive_selector_count + 1
                    end
                end
            end
        else
            tmp = {
                enable =  (v=="stat") and true or (self._plugin_cache:get(v .. ".enable") or false),
                name = v
            }
        end
        
        plugins[v] = tmp
    end

    return plugins
end

-----------------------------------------------------------------------------------------------------------------

return model
