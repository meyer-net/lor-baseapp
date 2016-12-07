-- 自定义函数指针
local require = require
local type = type
local pcall = pcall
local error = error

local s_find = string.find

local log = ngx.log
local log_debug = ngx.DEBUG
local log_err = ngx.ERR

-- 统一引用导入LIBS
local c_json = require("cjson.safe")
local u_io = require("app.utils.io")

-----------------------------------------------------------------------------------------------------------------

local _M = { _VERSION = '0.01' }

-- 加载配置文件
function _M.load_config(config_path)
    config_path = config_path or "./conf/vhosts/sys.conf"
    local config_contents = u_io.read_file(config_path)

    if not config_contents then
        log(log_err, "No configuration file at: ", config_path)
        os.exit(1)
    end

    local config = c_json.decode(config_contents)
    return config, config_path
end

--- Try to load a module.
-- Will not throw an error if the module was not found, but will throw an error if the
-- loading failed for another reason (eg: syntax error).
-- @param module_name Path of the module to load (ex: kong.plugins.keyauth.api).
-- @return success A boolean indicating wether the module was found.
-- @return module The retrieved module.
function _M.load_module_if_exists(module_name)
    local status, res = pcall(require, module_name)
    if status then
        return true, res
        -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
    elseif type(res) == "string" and s_find(res, "module '"..module_name.."' not found", nil, true) then
        return false
    else
        error(res)
    end
end

-----------------------------------------------------------------------------------------------------------------

return _M
