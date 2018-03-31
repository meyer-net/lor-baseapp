--[[
---> 统一函数指针
--]]
local require = require

local s_format = string.format

-----> 基础库引用
local r_http = require("resty.http")

-----> 工具引用
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")
local u_time = require("app.utils.time")

-----> 外部引用
local c_json = require("cjson.safe")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 上下文 操作区域 --------------------------------------------------------------------------------------------
---> 获取节假日类型，工作日对应结果为 0, 休息日对应结果为 1, 节假日对应的结果为 2，未取到数据默认的情况下为工作日
----> 参数格式为：20170502
function _M.get_day_type(date)
    date = date or u_time.current_day(ngx.today(), "%Y%m%d")

    local day_type = "0"
    local post_url = s_format("http://www.easybots.cn/api/holiday.php?d=%s&ak=%s", date, "k360.4422f6b94e70752a02a8ab6e77ebf2dd@inewmax.com")

    local http = r_http:new()
    local res, err = http:request_uri(post_url, {
        method = "GET",
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        }
    })
    
    if u_object.check(res) and u_object.check(res.body) then
        local data = c_json.decode(res.body)
        day_type = data[date]
    end

    return "0" --day_type
end

--[[
---> 判断当前时间是否为工作日
--]]
function _M.is_work_day(date)
    return _M.get_day_type(date) == "0"
end


--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M