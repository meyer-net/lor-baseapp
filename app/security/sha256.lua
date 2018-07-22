-- 
--[[
---> Sha256 加解密算法
--------------------------------------------------------------------------
---> 参考文献如下
-----> 
--------------------------------------------------------------------------
---> Examples：
-----> 
--]]
--
-----------------------------------------------------------------------------------------------------------------
--[[
---> 统一函数指针
--]]
local require = require
local s_byte = string.byte
local s_sub = string.sub
local s_char = string.char
local s_rep = string.rep
--------------------------------------------------------------------------
--[[
---> 统一引用导入APP-LIBS
--]]
--->
----->
--------------------------------------------------------------------------

-----> 基础库引用
local object = require("app.lib.classic")
local r_string = require("resty.string")
local r_sha256 = require("resty.sha256")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local obj = object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 obj.super.new(self, store, self._name)
--]]
function obj:new(name)
	-- 指定名称
    self._name = name or "sha256"
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> 编码
--]]
function obj:encode( source )
    local sha256 = r_sha256:new()
    sha256:update(source)
    local digest = sha256:final()
    return r_string.to_hex(digest)
end

-----------------------------------------------------------------------------------------------------------------

return obj