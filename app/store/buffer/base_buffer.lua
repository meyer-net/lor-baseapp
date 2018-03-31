-- 自定义函数指针
local type = type

local n_log = ngx.log
local n_err = ngx.ERR

local s_format = string.format

local u_object = require("app.utils.object")
local l_object = require("app.lib.classic")
local u_time = require("app.utils.time")
local u_string = require("app.utils.string")
local u_locker = require("app.utils.locker")

local _M = l_object:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -----------------------------------  

--[[
---> RDS 选区
--]]
function _M:new(conf)
    self._VERSION = '0.01'
	self._name = "buffer-base-store"
	
	self.conf = conf
	self.buffer_key_module = "buffer->topic{%s}%s"
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 过滤超时时间
--]]
function _M:filter_timeout( timeout , default )
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
---> 格式化键
--]]
function _M:topickey_format( key, partition )
	if type(partition) == "boolean" then
		if partition then
			partition = u_string.to_time(u_time.current_second())
		else
			partition = "full"
		end
	end
	
	return s_format(self.buffer_key_module, key, partition or "all")
end

--[[
---> 记录队列的键值，必须提前在配置文件中声明 lua_shared_dict sys_buffer_mq ${num}m;
---> 主要记录写入队列的keys，避免重复读取，避免数据沉淀冗余
--]]
function _M:record_mq_keys(store, source_key, format_key)
	local current_key = s_format(self.buffer_key_module, source_key, "mq_current")
	local mq_key = s_format(self.buffer_key_module, source_key, "mq_keys")

	if store then
		local ok, err = u_locker(store, mq_key):action("sys_buffer_locker", function ()
			return pcall(function()
				local mq_current = store:get(current_key)
				if mq_current ~= format_key then
					store:set(current_key, format_key)
					store:lpush(mq_key, format_key)
				end
            end)
		end)

		if not ok then
			n_log(n_err, err)
		end
		
		return ok, err
	end

	return false, "no store to save mq_keys"
end

-----------------------------------------------------------------------------------------------------------------

return _M