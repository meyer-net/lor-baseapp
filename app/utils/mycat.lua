--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_sub = string.sub

-----> 基础库引用
local r_http = require("resty.http")
local l_uuid = require("app.lib.uuid")

-----> 工具引用
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")

-----> 外部引用
local c_json = require("cjson.safe")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 上下文 操作区域 --------------------------------------------------------------------------------------------

--[[
---> 绑定日期与GID
--]]
function _M.bind_partition(data, date)
    date = date or ngx.today()
    data = data or {}

    if not data.id then
        data.id = l_uuid()
    end

    data.create_date = date
    data.gid = tonumber(s_sub(date, 9, 10))

    return data
end


--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M