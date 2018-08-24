local ipairs = ipairs
local pcall = pcall
local type = type
local require = require

local t_insert = table.insert
local t_sort = table.sort
local s_gsub = string.gsub
local s_format = string.format

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

local c_json = require("cjson.safe")
local u_loader = require("app.utils.loader")
local u_each = require("app.utils.each")
local u_table = require("app.utils.table")
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")

local r_plugin = require("app.model.repository.plugin_repo")

-------------------------------------------------- Plugins -------------------------------------------------


local loaded_plugins_handler = {}

-- ms
local function now()
    return ngx.now() * 1000
end

local function load_plugins_handler(config, store)
    n_log(n_debug, "Discovering used plugins")

    local sorted_plugins = {}
    local plugins = config.plugins

    u_each.array_action(plugins, function ( _, plugin_name )
        if (plugin_name ~= "micros") then
            local plugin_namespace = s_format("app.plugins.%s.handler", plugin_name)
            local loaded, plugin_handler = u_loader.load_module_if_exists(plugin_namespace)
            if not loaded then
                n_log(n_err, "The following plugin is not installed: " .. plugin_name)
            else
                n_log(n_debug, "Loading plugin: " .. plugin_name)
                local new_plugin = {
                    name = plugin_name,
                    handler = plugin_handler(config, store),
                }
                
                t_insert(sorted_plugins, new_plugin)
            end
        end
    end)

    t_sort(sorted_plugins, function(a, b)
        local priority_a = a.handler.PRIORITY or 5
        local priority_b = b.handler.PRIORITY or 5
        
        return priority_a > priority_b
    end)
    
    return sorted_plugins
end

-------------------------------------------------- ------ --------------------------------------------------

-------------------------------------------------- System --------------------------------------------------

local _obj = {}

-- 执行过程:
-- 加载配置
-- 实例化存储store
function _obj.init(options)
    options = options or {}
    local store, config
    local status, err = pcall(function()
        local force_plugins = {"stat", "micros", "map"}
        config = u_loader.load_config(options.config)
        config.plugins = config.plugins and u_table.merge(config.plugins, force_plugins) or config.plugins

        ctx_store = {
            db = { },
            cache = { },
            buffer = { },
            plugin = { }
        }

        -- 加载已声明的DB配置信息
        local db_configs = config.store["db_configs"]
        local config_module = db_configs["config_module"] or {}

        -- 填充DB操作模式
        u_each.json_action(db_configs, function ( k, v )
            -- 检测是否为配置节点
            if u_string.ends_with(k, "_config") then
                -- 将配置加载至节点
                local db_config = u_table.clone(config_module)
                db_config["timeout"] = db_configs.timeout

                -- 驱动节点填充
                local driver_config = db_configs[(v.driver or db_config.driver).."_module"]
                db_config = u_table.merge(driver_config, db_config)

                -- 实体节点填充
                db_config = u_table.merge(v, db_config)

                -- u_each.json_action(v, function ( key, value )
                --         -- 属性新增或覆盖
                --         db_config[key] = value
                --     end)

                -- 获取具体的驱动适配器
                local db_mode = db_config.mode or 'normal'
                local switch_db_namespace = ("app.store."..db_mode..".adapter")
                
                -- 添加到加载后的对象
                local db_key = s_gsub(k, "_config", "")
                ctx_store.db[db_key] = require(switch_db_namespace)(db_config):open()
                
                n_log(n_info, s_format("Loading db '%s:%s' from '%s', config: '%s'", db_mode, db_key, switch_db_namespace, c_json.encode(db_config)))
            end
        end)

        -- 设置默认
        local default_db = ctx_store.db["plugin"]
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
                    project_name = config.project_name,
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
        local find_ram_node = function (store_group, from_group)
            local using_config = config.store[store_group]
            if not using_config then
                return nil
            end

            local tmp_array = u_string.split_gsub(using_config, ".")
            local ram_type = tmp_array[1]
            local ram_mode = tmp_array[2] or "default"

            return ctx_store[from_group or store_group][ram_type][ram_mode]
        end
        
        ctx_store["cache"].using = find_ram_node("cache")
        ctx_store["buffer"].using = find_ram_node("buffer")
        ctx_store["plugin"] = find_ram_node("plugin", "cache")
        
        loaded_plugins_handler = load_plugins_handler(config, ctx_store)
        ngx.update_time()
        config.app_start_at = ngx.now()
    end)

    if not status or err then
        n_log(n_err, "Startup error: " .. err)
        os.exit(1)
    end

    _obj.data = {
        store = ctx_store,
        config = config
    }

    return config, ctx_store
end

function _obj.init_worker()
    -- 仅在 init_worker 阶段调用，初始化随机因子，仅允许调用一次
    math.randomseed(tostring(ngx.now()*1000):reverse())

    -- 初始化定时器，清理计数器等    
    local worker_id = ngx.worker.id()
    if worker_id == 0 then
        local ok, err = ngx.timer.at(0, function(premature, store, config)
            local current_repo = r_plugin(_obj.data.config, _obj.data.store)
            u_each.array_action(config.plugins, function (_, plugin)
                local load_success = current_repo:load_data_by_db(plugin)
                if not load_success then
                    os.exit(1)
                end
            end)
        end, _obj.data.store, _obj.data.config)

        if not ok then
            ngx.log(ngx.ERR, "failed to create the timer: ", err)
            return os.exit(1)
        end
    end

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        return plugin.handler:init_worker()
    end)
end

-- 执行阶段检测
function phase_exec(exec_action)
    -- 自请求不验证
    if not ngx.is_subrequest then
        exec_action()
    end
end

function _obj.redirect()
    ngx.ctx.APP_REDIRECT_START = now()

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:redirect()
        end)
    end)

    local now = now()
    ngx.ctx.APP_REDIRECT_TIME = now - ngx.ctx.APP_REDIRECT_START
    ngx.ctx.APP_REDIRECT_ENDED_AT = now
end

function _obj.rewrite()
    ngx.ctx.APP_REWRITE_START = now()

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:rewrite()
        end)
    end)

    local now = now()
    ngx.ctx.APP_REWRITE_TIME = now - ngx.ctx.APP_REWRITE_START
    ngx.ctx.APP_REWRITE_ENDED_AT = now
end


function _obj.access()
    ngx.ctx.APP_ACCESS_START = now()

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:access()
        end)
    end)

    local now = now()
    ngx.ctx.APP_ACCESS_TIME = now - ngx.ctx.APP_ACCESS_START
    ngx.ctx.APP_ACCESS_ENDED_AT = now
    ngx.ctx.ACCESSED = true
end

function _obj.header_filter()
    local HEADERS = {
        APP_LATENCY = "X-App-Latency",
        X_Powered_By = "X-Powered-By"
    }

    if ngx.ctx.ACCESSED then
        local now = now()
        ngx.ctx.APP_WAITING_TIME = now - ngx.ctx.APP_ACCESS_ENDED_AT -- time spent waiting for a response from upstream
        ngx.ctx.APP_HEADER_FILTER_STARTED_AT = now
    end

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:header_filter()
        end)
    end)

    if ngx.ctx.ACCESSED then
        ngx.header[HEADERS.APP_LATENCY] = ngx.ctx.APP_WAITING_TIME
    end

    ngx.header[HEADERS.X_Powered_By] = (_obj.data.config.company or "Meyer") .. " OShit Team"
end

function _obj.body_filter()
    -- local is_normal_request = u_object.check(ngx.arg[1]) and not ngx.is_subrequest
    -- if not is_normal_request then
    --     return
    -- end

    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:body_filter()
        end)
    end)

    local now = now()
    if ngx.ctx.ACCESSED then
        ngx.ctx.APP_RECEIVE_TIME = now - (ngx.ctx.APP_HEADER_FILTER_STARTED_AT or now)
    end
end

function _obj.log()
    u_each.array_action(loaded_plugins_handler, function ( _, plugin )
        phase_exec(function()
            plugin.handler:log()
        end)
    end)
end

-------------------------------------------------- ------ --------------------------------------------------

return _obj
