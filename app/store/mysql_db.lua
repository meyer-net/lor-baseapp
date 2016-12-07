local setmetatable = setmetatable

local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO

local mysql = require("resty.mysql")
local u_db = require("app.utils.db")
local _M = { _VERSION = '0.02' }

--[[
    创建实例
--]]
function _M:new(conf)
    return setmetatable({
            config = conf
        }, { __index = _M })
end

--[[
    执行
--]]
function _M:exec(sql)
    if not sql then
        local error_text = "MySQLDB -> exec => Sql parse error！Please check！"
        n_log(n_err, error_text)
        return nil, error_text
    end

    local config = self.config
    local db, err = mysql:new()
    if not db then
        n_log(n_err, "MySQLDB -> exec => Failed to instantiate mysql：", err)
        return
    end

    db:set_timeout(config.timeout) -- 1 sec

    local ok, err, errno, sqlstate = db:connect(config.connect_config)
    if not ok then
        n_log(n_err, "MySQLDB -> exec => Failed to connect：", err, "：", errno, " ", sqlstate)
        return
    end

    -- n_log(n_info, "MySQLDB -> exec => Connected to mysql, reused_times:", db:get_reused_times(), " sql:", sql)

    db:query("SET NAMES utf8")
    local res, err, errno, sqlstate = db:query(sql)
    if not res then
        n_log(n_err, "MySQLDB -> exec => Bad result：", err, "：", errno, "：", sqlstate, ".")
    end

    local ok, err = db:set_keepalive(config.pool_config.max_idle_timeout, config.pool_config.pool_size)
    if not ok then
        n_log(n_err, "MySQLDB -> exec => Failed to set keepalive：", err)
    end

    return res, err, errno, sqlstate
end

--[[
    查询
        返回结果数据集
    返回:
        bool,出错信息,错误代码,sqlstate结构.
--]]
function _M:query(sql, params)
    sql = u_db.parse_sql(sql, params)
    return self:exec(sql)
end

--[[
    搜索
--]]
function _M:select(sql, params)
    return self:query(sql, params)
end

--[[
    插入
--]]
function _M:insert(sql, params)
    local res, err, errno, sqlstate = self:query(sql, params)
    n_log(n_err, require("cjson.safe").encode(res))
    if res and not err then
        return  res.insert_id, err
    else
        return res, err
    end
end

--[[
    更新
--]]
function _M:update(sql, params)
    return self:query(sql, params)
end

--[[
    删除
--]]
function _M:delete(sql, params)
    local res, err, errno, sqlstate = self:query(sql, params)
    if res and not err then
        return res.affected_rows, err
    else
        return res, err
    end
end

return _M