-- 
--[[
---> AES 加解密算法
--------------------------------------------------------------------------
---> 参考文献如下
-----> https://github.com/openresty/lua-resty-string#table-of-contents
-----> https://my.oschina.net/Jacker/blog/86383
--------------------------------------------------------------------------
---> Examples：
-----> local s_aes = require("app.security.aes")
-----> local n_aes = s_aes()
-----> local key = "12345678901234561234567890123456"

-----> local encrypted_base64 = n_aes:encrypt_tob64(key, req.params.data)
-----> res:send(encrypted_base64)

-----> local decrypted_text = n_aes:decrypt_fromb64(key, encrypted_base64)
-----> res:send(decrypted_text)
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
local r_aes = require("resty.aes")

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
    self._name = name or "aes pkcs7"
end

-----------------------------------------------------------------------------------------------------------------

--[[
---> AES 加密
--]]
function obj:encrypt_tob64( key, data )
	local block_size = 32
	local pad = block_size - (#data % block_size)
	local ept_data = data .. s_rep(s_char(pad), pad)

	local aes = r_aes:new(
	        key,
	        nil,
	        r_aes.cipher(256,"cbc"),
	        { iv = s_sub(key,1,16) },
	        nil,
	        0
	    )

	-- AES 128 CBC with IV and no SALT
	local encrypted = aes:encrypt(ept_data)
	local encrypted_base64 = ngx.encode_base64(encrypted)-- r_string.to_hex(encrypted)

    return encrypted_base64
end

--[[
---> AES 解密
--]]
function obj:decrypt_fromb64( key, decrypt_base64 )
	local aes = r_aes:new(
	        key,
	        nil,
	        r_aes.cipher(256,"cbc"),
	        { iv = s_sub(key,1,16) },
	        nil,
	        0
	    )

	local encrypted = ngx.decode_base64(decrypt_base64)
    local decrypted = aes:decrypt(encrypted)
    local pad = s_byte(s_sub(decrypted, #decrypted))
    local decrypted_text = s_sub(decrypted, 1, #decrypted-pad)

    return decrypted_text
end

-----------------------------------------------------------------------------------------------------------------

return obj