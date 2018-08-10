local u_base = require("app.utils.base")
local model = u_base:extend()

function model:new(name)
    self._name = ( name or "anonymity" ) .. " store"

	-- 传导至父类填充基类操作对象
    model.super.new(self, name)
end

function model:set(k, v)
    if not k or k == "" then return false, "nil key." end
    
    ngx.log(ngx.DEBUG, " store \"" .. self._name .. "\" get:" .. k)
end

function model:get(k)
    if not k or k == "" then return nil end

    ngx.log(ngx.DEBUG, " store \"" .. self._name .. "\" set:" .. k, " v:", v)
end

return model