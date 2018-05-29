--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_sub = string.sub

local n_var = ngx.var
local n_log = ngx.log
local n_err = ngx.ERR
local n_info = ngx.INFO
local n_debug = ngx.DEBUG

--------------------------------------------------------------------------

-----> 基础库引用
local l_object = require("app.lib.classic")

-----> 工具引用
local r_jwt = require("resty.jwt")
local u_string = require("app.utils.string")
local u_object = require("app.utils.object")
local u_request = require("app.utils.request")
local ue_error = require("app.utils.exception.error")

-----> 外部引用
local c_json = require("cjson.safe")

-----------------------------------------------------------------------------------------------------------------

--[[
---> 当前对象
--]]
local _obj = l_object:extend()

--[[
---> 实例构造器
------> 子类构造器中，必须实现 _obj.super.new(self, self._name, self._cache)
--]]
function _obj:new(name, cache)
    self._name = s_format("[%s]-jwt", name or self._name)
    self._request = u_request(self._name)
    self._cache = cache
end

-- 通用事件码
local EVENT_CODE = ue_error.EVENT_CODE

---> 上下文 操作区域 --------------------------------------------------------------------------------------------

-- 生成
function _obj:check(payload)
    if not u_object.check(payload) then
        return false, "can not load payload, please sure your return is up to standard"
    end

    if not payload.iss or not payload.aud or not payload.jti then
        return false, "can not load the necessary payload data like 'iss, aud, jti', please sure all of the property exists"
    end

    return true
end

-- 生成JWT密钥信息
function _obj:gen_secret(iss, aud, jti)
    local client_type = self._request:get_client_type()
    return s_format("jwt-(%s!%s/%s)-%s", iss, aud, client_type, jti)
end

-- 生成JWT信息
-- payload 结构：{ security_code, prev_security_code, uid, exp }
-- 如下为标准字段
--[[
    iss：Issuer，发行者
    sub：Subject，主题
    aud：Audience，观众
    exp：Expiration time，过期时间
    nbf：Not before
    iat：Issued at，发行时间
    jti：JWT ID
    iat：令牌生成时间
]]--
function _obj:generate(payload)
    local secret = self:gen_secret(payload.iss, payload.aud, payload.jti)

    payload.csrf_token = u_string.gen_random_string()  -- 优化时，可以加入令牌池，进行状态调整
    payload.client_type = self._request:get_client_type()
    payload.client_host = self._request:get_client_host()

    local jwt = r_jwt:sign(secret, {
        header = {
            typ = "JWT", 
            alg = "HS512"
        },
        payload = payload
    })

    return secret, jwt
end

-- 加载payload信息
function _obj:load(jwt, csrf_token)
    local return_payload = nil
    local event_code = EVENT_CODE.jwt_missing
    local secret = ""
    
    if u_object.check(jwt) then
        --[[
            jwt_model: {
                "raw_header": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9",
                "raw_payload: "eyJmb28iOiJiYXIifQ",
                "signature": "wrong-signature",
                "header": {"typ": "JWT", "alg": "HS256"},
                "payload": {"foo": "bar"},
                "verified": false,
                "valid": true,
                "reason": "signature mismatched: wrong-signature"
            }
        ]]--
        local jwt_model = r_jwt:load_jwt(jwt)
        local client_host = self._request:get_client_host()
        local payload = jwt_model.payload
        secret = self:gen_secret(payload.iss, payload.aud, payload.jti)
        local jwt_verified = r_jwt:verify_jwt_obj(secret, jwt_model)
        
        -- local jwt_model = jwt and r_jwt:verify(secret, jwt)
        -- local jwt_verified = jwt_model and jwt_model.verified
        if jwt_verified then
            if payload.csrf_token ~= csrf_token then
                event_code = EVENT_CODE.jwt_invalid
                n_log(n_info, s_format("[load-jwt]csrf ident raise error, jwt-csrf: %s - cookie-csrf: %s", payload.csrf_token, csrf_token))
            elseif payload.client_host ~= client_host then
                event_code = EVENT_CODE.env_expired
                n_log(n_debug, s_format("[load-jwt]client env changed error, jwt-host: %s - dynamic-host: %s - %s", payload.client_host, client_host, c_json.encode(payload)))
            else
                local cache_jwt = self._cache:get(secret)
                if not cache_jwt then
                    event_code = EVENT_CODE.jwt_expired
                    n_log(n_debug, s_format("[load-jwt]can not find jwt from cache, secret: %s, client: %s", secret, jwt))
                elseif cache_jwt ~= jwt then
                    event_code = EVENT_CODE.crowded_offline
                    n_log(n_debug, s_format("[load-jwt]jwt conflict, secret: %s, cache: %s - client: %s", secret, cache_jwt, jwt))
                else
                    return_payload = jwt_model.payload
                    event_code = EVENT_CODE.normal
                end
            end
        else
            event_code = EVENT_CODE.jwt_err
            n_log(n_debug, s_format("[load-jwt]jwt verified faild, secret: %s, client: %s", secret, jwt))
        end
    end

    return event_code == EVENT_CODE.normal, event_code, secret, return_payload
end

--[[
---> 
--]]
--function _obj.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _obj