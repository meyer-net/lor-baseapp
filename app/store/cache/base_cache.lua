-- 自定义函数指针
local type = type
local setmetatable = setmetatable

local s_find = string.find
local t_insert = table.insert
local t_remove = table.remove

local u_object = require("app.utils.object")
local u_base = require("app.utils.base")

local model = u_base:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -----------------------------------  

--[[
---> RDS 选区
--]]
function model:new(conf, name)
	self._VERSION = '0.02'
	
    local name = name or "cache-base-store"

	-- 传导至父类填充基类操作对象
    model.super.new(self, name)

    self.config = conf
end

--[[
---> 过滤超时时间
--]]
function model.filter_timeout( timeout , default )
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

--[[
---> 缓存记录追加
--]]
function model:append(key, item, limit)
	local arr_temp = self:get(key)
	if not arr_temp then
		arr_temp = {}
	else
		arr_temp = self.utils.json.decode(arr_temp)
	end

	local arr_len = #arr_temp
	t_insert(arr_temp, item)

	if limit and arr_len >= limit then
       	t_remove(arr_temp, 1)
	end

	return self:set(key, self.utils.json.encode(arr_temp))
end

-----------------------------------------------------------------------------------------------------------------

return model