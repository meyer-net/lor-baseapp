local object = require "app.lib.classic"
local _M = object:extend()

function _M:new(name)
    self._name = name
end

function _M:set(k, v)
    if not k or k == "" then return false, "nil key." end
    
    ngx.log(ngx.DEBUG, " store \"" .. self._name .. "\" get:" .. k)
end


function _M:get(k)
    if not k or k == "" then return nil end

    ngx.log(ngx.DEBUG, " store \"" .. self._name .. "\" set:" .. k, " v:", v)
end

return _M