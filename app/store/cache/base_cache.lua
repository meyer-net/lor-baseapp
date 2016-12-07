-- 自定义函数指针
local type = type
local setmetatable = setmetatable

local s_find = string.find

local u_object = require("app.utils.object")
local object = require("app.lib.classic")

local _M = object:extend()
_M._VERSION = '0.01'

------------------------------------------ 通用配置信息，使它分离出多个区域 -----------------------------------  

--[[
---> 过滤超时时间
--]]
function _M.filter_timeout( timeout , default )
	local this_timeout = timeout
	if not u_object.check(timeout) then
		if type(default) == "number" then
			this_timeout = default
		end
	else
		if type(default) == "function" then
			default()
		end
	end

	--if this_timeout <= 0 then
	--	this_timeout = 2^53
	--end

	return this_timeout
end

-----------------------------------------------------------------------------------------------------------------

return _M