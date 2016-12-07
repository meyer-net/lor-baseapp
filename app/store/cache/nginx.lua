-- 自定义函数指针
local type = type

local c_json = require("cjson.safe")
local u_each = require("app.utils.each")
local s_cache = require("app.store.cache.base_cache")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_cache:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -------------------------------------

--[[
---> RDS 选区
--]]
function _obj:new(conf)
    self._VERSION = '0.02'
    self._name = "cache-nginx-store"
    self.store = ngx.shared[conf.name]

    _obj.super.new(self, self._name)
end

-----------------------------------------------------------------------------------------------------------------

----------------------------------------------- NGX 缓存设置 ----------------------------------------------------

-- 设置 NGX 缓存值
function _obj:set_by_json(list, timeout)
	local ok,err,effect_len,forcible = "","",0,""
	timeout = _obj.filter_timeout(timeout, 0)
	local json_obj = c_json.decode(list)
	u_each.json_action(json_obj, function(k,v)
		ok,err,forcible = self.store:set(k, v, timeout)

		if not err then
			effect_len = effect_len + 1
		end
	end)

	return ok,err,effect_len,forcible
end

-- 设置 NGX 缓存值
function _obj:set(key, value, timeout)
	timeout = _obj.filter_timeout(timeout, 0)

	return self.store:set(key, value, timeout)
end

-- 设置 NGX 缓存值 依据 function
function _obj:set_by_func(key, func, timeout)
	timeout = _obj.filter_timeout(timeout, 0)

	return self.store:set(key, func(), timeout)
end

-- 获取 NGX 缓存值
function _obj:get(key)
	local status,value,effect_len = "OK",nil,0
	local value,err = self.store:get(key)
	if not value then
		status = "FAILURE"
	else
		effect_len = 1
	end

	return value,err,effect_len,status
end

-----------------------------------------------------------------------------------------------------------------

function _obj:delete(key)
    self.store:delete(key)
end

function _obj:delete_all()
    self.store:flush_all()
    self.store:flush_expired()
end

function _obj:incr(key, step, timeout)
	timeout = _obj.filter_timeout(timeout, 0)

	return self.store:incr(key, step, timeout)
end

function _obj:keys(pattern)
	if not pattern then
		pattern = 0
	end
	
    return self.store:get_keys(pattern)
end

-----------------------------------------------------------------------------------------------------------------

return _obj