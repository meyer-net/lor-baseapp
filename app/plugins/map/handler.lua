-- 
--[[
---> 用于将当前插件提供为具体系统的上下文
--------------------------------------------------------------------------
---> 参考文献如下
-----> /
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
--------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------

--[[
---> 统一引用导入APP-LIBS
--]]
--------------------------------------------------------------------------
-----> 基础库引用
local p_base = require("app.plugins.handler_adapter")
local u_loader = require("app.utils.loader")

--------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local handler = p_base:extend()

-----------------------------------------------------------------------------------------------------------------

--[[
---> 实例构造器
------> 子类构造器中，必须实现 handler.super.new(self, name)
--]]
function handler:new(conf, store)
    -- 优先级调控
    self.PRIORITY = 2

    -- 插件名称
    self._source = "map"

	-- 传导至父类填充基类操作对象
    handler.super.new(self, conf, store)
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 子执行器
--]]
function handler:_exec_action(action)
    self:exec_action(function (pointer, rule, variables, conditions_matched)
        local plugin_namespace = pointer.format("app.plugins.%s.handler", rule.plugin)
        local loaded, plugin_handler = u_loader.load_module_if_exists(plugin_namespace)
        if loaded then
            local hdl = plugin_handler(pointer._conf, pointer._store)
            local action_func = hdl[pointer.format("_%s_action", action)]

            -- 单个插件的事件执行完了，则跳出
            if action_func then
                hdl:_rule_action(rule, action_func)
            end
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------

function handler:redirect()
    -- self._log.err("load exec redirect")
    self:_exec_action("redirect")
end

function handler:rewrite()
    -- self._log.err("load exec rewrite")
    self:_exec_action("rewrite")
end

function handler:access()
    -- self._log.err("load exec access")
    self:_exec_action("access")
end

function handler:header_filter()
    -- self._log.err("load exec header_filter")
    self:_exec_action("header_filter")
end

function handler:body_filter()
    local is_normal_request = self.utils.object.check(ngx.arg[1]) and not ngx.is_subrequest
    if not is_normal_request then
        return
    end

    -- self._log.err("load exec body_filter")
    self:_exec_action("body_filter")
end

function handler:log()
    -- self._log.err("load exec log")
    self:_exec_action("log")
end

-----------------------------------------------------------------------------------------------------------------

return handler