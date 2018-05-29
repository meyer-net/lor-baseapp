--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_sub = string.sub

-----> 基础库引用
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
---> 用于获取源自GET/POST中的数据
--]]
function _M.get_args(req)
    local params = u_object.set_if_empty(ngx.var.args, function()
        return c_json.encode(req.body)
    end)

    return params
end


--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M