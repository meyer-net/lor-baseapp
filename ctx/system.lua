local ipairs = ipairs
local pcall = pcall
local type = type
local require = require

local t_insert = table.insert
local t_sort = table.sort
local s_gsub = string.gsub

local n_log = ngx.log
local n_err = ngx.ERR
local n_debug = ngx.DEBUG

local u_loader = require("app.utils.loader")
local u_each = require("app.utils.each")
local u_string = require("app.utils.string")

-------------------------------------------------- Plugins -------------------------------------------------

local HEADERS = {
    APP_LATENCY = "X-App-Latency",
    X_Powered_By = "X-Powered-By"
}

local loaded_plugins = {}

-- ms
local function now()
    return ngx.now() * 1000
end

local function load_plugins_handler(config, store)
    n_log(n_debug, "Discovering used plugins")

    local sorted_plugins = {}
    local plugins = config.plugins

    for _, v in ipairs(plugins) do
        local loaded, plugin_handler = u_loader.load_module_if_exists("app.plugins." .. v .. ".handler")
        if not loaded then
            n_log(n_err, "The following plugin is not installed: " .. v)
        else
            n_log(n_debug, "Loading plugin: " .. v)
            t_insert(sorted_plugins, {
                name = v,
                handler = plugin_handler(store, config),
            })
        end
    end

    t_sort(sorted_plugins, function(a, b)
        local priority_a = a.handler.PRIORITY or 0
        local priority_b = b.handler.PRIORITY or 0
        return priority_a > priority_b
    end)

    return sorted_plugins
end

-------------------------------------------------- ------ --------------------------------------------------

-------------------------------------------------- System --------------------------------------------------

local _M = {}

-- 执行过程:
-- 加载配置
-- 实例化存储store
function _M.init(options)
    options = options or {}
    local store, config
    local status, err = pcall(function()
        local conf_file_path = options.config

        config = u_loader.load_config(conf_file_path)

        local db_store = require("app.store."..config.store.db.."_store")(config.store["db_"..config.store.db])

        store = {
            db = db_store,
            cache = { }
        }

        local using_cache = config.store.cache
        local cache_adapter = require("app.store.cache_adapter")
        local cache_store = require("app.store.cache_store")

        -- 存储对象遍历
        u_each.json_action(config.store, function ( k, v )
            -- 加载所有已声明的缓存信息，例如：cache_nginx
            if u_string.starts_with(k, "cache_") then
                local cache_node = config.store[k]
                local cache_type = s_gsub(k, "cache_", "")

                -- 对象初始化，例如 cache.nginx，cache.redis
                local cache_group = {}

                -- 填充缓存分组对象
                local fill_cache_group = function ( node, cfg )
                    local options = {
                        name = node,
                        cache_type = cache_type,
                        locker_name = config.store.locker_name,
                        config = cfg
                    }

                    cache_group[node] = cache_store(options)
                end

                -- 缓存配置解析填充器
                local switch = {
                    ['nginx'] = function()    -- for case nginx
                        u_each.array_action(cache_node, function ( _, item )
                                fill_cache_group(item, { name = item })
                            end)
                    end,
                    ['redis'] = function()    -- for case redis
                        u_each.json_action(cache_node, function ( node, cfg )
                                fill_cache_group(node, cfg)
                            end)

                    end
                }

                -- 执行当前配置逻辑
                switch[cache_type]()

                store.cache[cache_type] = cache_group
            end
        end)

        local tmp_array = u_string.split_gsub(using_cache, ".")
        local cache_type = tmp_array[1]
        local cache_node = tmp_array[2] or "default"

        -- store.cache.using.cache.config.port
        store.cache.using = store.cache[cache_type][cache_node]

        loaded_plugins = load_plugins_handler(config, store)
        ngx.update_time()
        config.app_start_at = ngx.now()
    end)

    if not status or err then
        n_log(n_err, "Startup error: " .. err)
        os.exit(1)
    end

    _M.data = {
        store = store,
        config = config
    }

    return config, store
end

function _M.init_worker()
    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:init_worker()
    end
end

function _M.redirect()
    ngx.ctx.APP_REDIRECT_START = now()

    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:redirect()
    end

    local now = now()
    ngx.ctx.APP_REDIRECT_TIME = now - ngx.ctx.APP_REDIRECT_START
    ngx.ctx.APP_REDIRECT_ENDED_AT = now
end

function _M.rewrite()
    ngx.ctx.APP_REWRITE_START = now()

    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:rewrite()
    end

    local now = now()
    ngx.ctx.APP_REWRITE_TIME = now - ngx.ctx.APP_REWRITE_START
    ngx.ctx.APP_REWRITE_ENDED_AT = now
end


function _M.access()
    ngx.ctx.APP_ACCESS_START = now()

    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:access()
    end

    local now = now()
    ngx.ctx.APP_ACCESS_TIME = now - ngx.ctx.APP_ACCESS_START
    ngx.ctx.APP_ACCESS_ENDED_AT = now
    ngx.ctx.ACCESSED = true
end

function _M.header_filter()

    if ngx.ctx.ACCESSED then
        local now = now()
        ngx.ctx.APP_WAITING_TIME = now - ngx.ctx.APP_ACCESS_ENDED_AT -- time spent waiting for a response from upstream
        ngx.ctx.APP_HEADER_FILTER_STARTED_AT = now
    end

    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:header_filter()
    end

    if ngx.ctx.ACCESSED then
        ngx.header[HEADERS.APP_LATENCY] = ngx.ctx.APP_WAITING_TIME
    end

    ngx.header[HEADERS.X_Powered_By] = (_M.data.config.company or "INewMax") .. " App-Framework"
end

function _M.body_filter()
    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:body_filter()
    end

    if ngx.ctx.ACCESSED then
        ngx.ctx.APP_RECEIVE_TIME = now() - ngx.ctx.APP_HEADER_FILTER_STARTED_AT
    end
end

function _M.log()
    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:log()
    end
end

-------------------------------------------------- ------ --------------------------------------------------

return _M
