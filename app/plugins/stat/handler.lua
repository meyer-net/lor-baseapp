--
--[[
---> 用于统计各接口流量信息。
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local base_handler = require("app.plugins.handler_adapter")
local p_stat = require("app.plugins.stat.stat")

--------------------------------------------------------------------------

--[[
---> 实例信息及配置
--]]
local handler = base_handler:extend()

handler.PRIORITY = 9999

function handler:new(conf, store)
    -- 控件名称
    self._source = "stat"

    handler.super.new(self, conf, store)  --, "stat-plugin"
end

--------------------------------------------------------------------------

function handler:init_worker(conf)
    p_stat.init()
end

function handler:log(conf)
    p_stat.log()
end

return handler
