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
local u_table = require("app.utils.table")
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
        config = u_loader.load_config(options.config)

        local db_mode = config.store["db_mode"] or 'normal'

        ctx_store = {
            db = { },
            cache = { },
            buffer = { }
        }

        -- 加载已声明的DB配置信息
        local db_configs = config.store["db_configs"]
        local config_module = db_configs["config_module"] or {}

        -- 填充DB操作模式
        local switch_db_namespace = ("app.store."..db_mode..".adapter")
        u_each.json_action(db_configs, function ( k, v )
            -- 检测是否为配置节点
            if u_string.ends_with(k, "_config") then
                -- 将配置加载至节点
                local db_config = u_table.clone(config_module)
                db_config["driver"] = config.store.db_driver
                db_config["timeout"] = db_configs.timeout

                u_each.json_action(v, function ( key, value )
                        -- 属性新增或覆盖
                        db_config[key] = value
                    end)

                -- 添加到加载后的对象
                local db_key = s_gsub(k, "_config", "")
                ctx_store.db[db_key] = require(switch_db_namespace)(db_config):open()
            end
        end)

        -- 设置默认
        local default_db = ctx_store.db["default"]
        if not default_db then
            ctx_store.db[""] = default_db
        else
            ctx_store.db[""] = ctx_store.db[1]
        end

        local fill_ram_lib_dict = function (store_group, ram_type, ram_type_config)
            -- 获取store
            local ram_store_lib = require("app.store."..store_group.."_store")

            -- 执行当前配置逻辑
            if not u_table.contains(ram_store_lib.support_types, ram_type) then
                return nil
            end
            
            -- 对象初始化，例如 ram.nginx，ram.redis，ram.kafka
            ctx_store[store_group][ram_type] = { }

            -- 填充缓存分组对象
            local fill_ram_group = function ( node, conf )
                local options = {
                    name = node,
                    store_group = ram_type,
                    db_mode = db_mode,
                    prject_name = config.project_name,
                    locker_name = config.store.locker_name,
                    conf = conf
                }
                
                -- buffer kafka cluster | cache nginx sys_locker | cache redis default | ...
                ctx_store[store_group][ram_type][node] = ram_store_lib(options)
            end

            -- 缓存配置解析填充器
            local switch_fill_func = {
                ['nginx'] = function()    -- for case nginx
                    u_each.array_action(ram_type_config, function ( _, item )
                            fill_ram_group(item, { name = item })
                        end)
                end,
                ['redis'] = function()    -- for case redis
                    u_each.json_action(ram_type_config, function ( node, conf )
                            fill_ram_group(node, conf)
                        end)
                end,
                ['kafka'] = function()    -- for case kafka
                    u_each.json_action(ram_type_config, function ( node, conf )
                            fill_ram_group(node, conf)
                        end)
                end
            }
            
            switch_fill_func[ram_type]()
        end

        -- 存储对象遍历，绑定配置文件节点，存储配置信息
        u_each.json_action(config.store, function ( k, v )
            -- 加载所有已声明的缓存信息，例如：ram_nginx
            if u_string.starts_with(k, "ram_") then
                local ram_type = s_gsub(k, "ram_", "")
                local ram_type_config = v -- config.store[k]

                fill_ram_lib_dict("cache", ram_type, ram_type_config)
                fill_ram_lib_dict("buffer", ram_type, ram_type_config)
            end
        end)

        -- 绑定默认使用对象
        local bind_store_using = function (store_group)
            local using_config = config.store[store_group]
            local tmp_array = u_string.split_gsub(using_config, ".")
            local ram_type = tmp_array[1]
            local ram_mode = tmp_array[2] or "default"

            ctx_store[store_group].using = ctx_store[store_group][ram_type][ram_mode]
        end

        bind_store_using("cache")
        bind_store_using("buffer")
        
        loaded_plugins = load_plugins_handler(config, ctx_store)
        ngx.update_time()
        config.app_start_at = ngx.now()
    end)

    if not status or err then
        n_log(n_err, "Startup error: " .. err)
        os.exit(1)
    end

    _M.data = {
        store = ctx_store,
        config = config
    }

    return config, ctx_store
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

    ngx.header[HEADERS.X_Powered_By] = (_M.data.config.company or "Meyer") .. " OShit Team"
end

function _M.body_filter()
    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:body_filter()
    end

    local now = now()
    if ngx.ctx.ACCESSED then
        ngx.ctx.APP_RECEIVE_TIME = now - (ngx.ctx.APP_HEADER_FILTER_STARTED_AT or now)
    end
end

function _M.log()
    for _, plugin in ipairs(loaded_plugins) do
        plugin.handler:log()
    end
end

-------------------------------------------------- ------ --------------------------------------------------

return _M
