--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_sub = string.sub

-----> 基础库引用
-- local l_uuid = require("app.lib.uuid")

-----> 工具引用
-- local u_string = require("app.utils.string")
-- local u_object = require("app.utils.object")

-----> 外部引用
local c_json = require("cjson.safe")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 上下文 操作区域 --------------------------------------------------------------------------------------------

--[[
---> 通用事件码
--]]
_M.EVENT_CODE = {
    normal = 0,                -- 正常
    param_empty = 1,           -- 参数错误
    param_format_err = 2,      -- 参数格式错误
    flow_err = 3,              -- 流程错误
    program_err = 4,           -- 程序错误
    api_err = 5,               -- 接口不存在、异常
    frequency_too_fast = 6,    -- 频率过快
    upload_err = 7,            -- 上传错误
    jwt_missing = 8,           -- 授权码丢失
    jwt_invalid = 9,           -- 授权码失效
    jwt_expired = 10,          -- 授权码过期
    jwt_err = 11,              -- 验签错误
    illegal = 12,              -- 非法请求
    unauthorized = 13,         -- 未授权访问
    env_expired = 14,          -- 环境发生变化
    crowded_offline = 15       -- 客户端从别处登录
}

function _M.switch_event_code_text ( event_code )
    local switch = {
        [_M.EVENT_CODE.normal] =                 "正常",
        [_M.EVENT_CODE.param_empty] =            "参数错误",
        [_M.EVENT_CODE.param_format_err] =       "参数格式错误",
        [_M.EVENT_CODE.flow_err] =               "流程错误",
        [_M.EVENT_CODE.program_err] =            "程序错误",
        [_M.EVENT_CODE.api_err] =                "接口不存在、异常",
        [_M.EVENT_CODE.frequency_too_fast] =     "频率过快",
        [_M.EVENT_CODE.upload_err] =             "上传错误",
        [_M.EVENT_CODE.jwt_missing] =            "会话超时",
        [_M.EVENT_CODE.jwt_invalid] =            "授权码失效",
        [_M.EVENT_CODE.jwt_expired] =            "授权码过期",
        [_M.EVENT_CODE.jwt_err] =                "验签错误",
        [_M.EVENT_CODE.illegal] =                "非法请求",
        [_M.EVENT_CODE.unauthorized] =           "未授权访问",
        [_M.EVENT_CODE.env_expired] =            "环境发生变化",
        [_M.EVENT_CODE.crowded_offline] =        "客户端从别处登录"
    }

    return switch[event_code] or "未知错误"
end

function _M.get_err( event_code, err, dt )
    return {
        res = false,
        ec = event_code,
        msg = err or _M.switch_event_code_text ( event_code ),
        dt = dt or {}
    }
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M