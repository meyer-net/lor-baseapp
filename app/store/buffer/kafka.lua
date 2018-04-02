-- 自定义函数指针
local type = type
local s_format = string.format

local u_object = require("app.utils.object")
local u_table = require("app.utils.table")

local r_kafka_procdure = require "resty.kafka.producer"
local s_buffer = require("app.store.buffer.base_buffer")

-----------------------------------------------------------------------------------------------------------------

local _obj = s_buffer:extend()

------------------------------------------ 通用配置信息，使它分离出多个区域 -------------------------------------

--[[
---> RDS 选区
--]]
function _obj:new(conf)
    self._VERSION = '0.01'
    self._name = "buffer-kafka-store"

    -- Kafka broker list 的特殊性，必须转换为数组
    conf = u_table.to_array(conf)
    
    -- try..catch 结构可参考https://github.com/tboox/xmake实现
    _obj.super.new(self, conf)
end

-----------------------------------------------------------------------------------------------------------------

-- 推送 KAFKA 缓冲值
-- 返回 offset, err
function _obj:push(key, value, partition)
    local client = require("resty.kafka.client"):new(self.conf)
    local brokers, partitions = client:fetch_metadata(key)
    if not brokers then
        return false, s_format("fetch_metadata failed, err: %s", partitions)
    end

    if not self.store then
        local options = nil
        if self.conf[1] and self.conf[1].producer_type then
            options = { producer_type = self.conf.producer_type or "async" }
        end
        self.store = r_kafka_procdure:new(self.conf, options)
    end

    -- 发送日志消息,send第二个参数key,用于kafka路由控制:  
    -- partition为nill(空)时，一段时间向同一partition写入数据  
    -- 指定partition，按照partition的hash写入到对应的partition  
    if type(partition) ~= "number" then
        partition = nil
    end

    local offset, err = self.store:send(key, partition, value)
    
    return not u_object.check(err), err, tonumber(offset) or "no partition"
end

-- 推送 KAFKA 缓冲值
function _obj:lpush(key, value, partition)
    return self:push(key, value, partition)
end

-- 推送 KAFKA 缓冲值
function _obj:rpush(key, value, partition)
    return self:push(key, value, partition)
end

-----------------------------------------------------------------------------------------------------------------

return _obj