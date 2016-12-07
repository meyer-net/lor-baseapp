local m_floor = math.floor

local date = require("app.lib.date")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 上下文 操作区域 --------------------------------------------------------------------------------------------
---> 获取已注册时间
function _M.days_after_registry(req)
    local diff = 0
    local diff_days = 0 -- default value, days after registry

    if req and req.session then
        local user = req.session.get("user")
        local create_time = user.create_time
        if create_time then
            local now = date() -- seconds
            create_time = date(create_time)
            diff = date.diff(now, create_time):spandays()
            diff_days = m_floor(diff)
        end
    end

    return diff_days, diff
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M