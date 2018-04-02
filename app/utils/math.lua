local tostring = tostring
local tonumber = tonumber

local s_format = string.format
local s_find = string.find
local s_gsub = string.gsub

local m_random = math.random
local m_modf = math.modf
local m_ceil = math.ceil
local m_floor = math.floor

local t_insert = table.insert

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 数学 操作区域 ----------------------------------------------------------------------------------------------

--[[
-----> 返回随机数
--]]
function _M.random(n1, n2)
    -- 纯为了防止并发，影响随机数生成
    ngx.sleep(0.001)

    -- lua 中特殊规则，需提前设置
    math.randomseed(tostring(ngx.now()*1000):reverse():sub(1, 9))

    if n1 and not n2 then
        return m_random(n1)
    end

    if n1 and n2 then
        return m_random(n1, n2)
    end

    return m_random()
end

--[[
-----> 四舍五入，弥补原生MATH库缺失
--]]
function _M.round(decimal)
    return m_floor((decimal * 100)+0.5)*0.01
end

--[[
-----> 保留N位小数
--]]
function _M.keep_decimal(decimal, d_len)
    d_len = d_len or 0
    return s_format("%0."..d_len.."f", decimal)
end

--[[
-----> 返回范围内随机数
--]]
function _M.random_range(range_begin, range_end)
    local range = range_end - range_begin
    local rand = _M.random()
    
    local num = range_begin + _M.round(rand * range) -- 四舍五入
    return tonumber(num, 10)
end

--[[
-----> 返回比例内随机数
--]]
function _M.random_per(base_value, per, is_up)
    local range_begin = base_value
    local range_end = base_value

    if is_up ~= nil then
        if not is_up then
            range_begin = m_floor(base_value - base_value * per)
        else
            range_end = m_ceil(base_value + base_value * per)
        end
    else
        if _M.random() >= 0.5 then
            range_begin = m_floor(base_value - base_value * per)
        else
            range_end = m_ceil(base_value + base_value * per)
        end
    end

    return _M.random_range(range_begin, range_end)
end

--[[
---> 返回平均数
--]]
function _M.avg(array_nums)
    local total = 0
    for _, v in ipairs(array_nums) do
        total = total + v
    end
    return total / #array_nums
end

--[[
-----> 计算分页
--]]
function _M.total_page(total_count, page_size)
    local total_page = 0
    if total_count % page_size == 0 then
        total_page = total_count / page_size
    else
        local tmp, _ = m_modf(total_count/page_size)
        total_page = tmp + 1
    end

    return total_page
end

--[[
-----> 计算分页
--]]
function _M.eval(calc_string)
    local script = s_format("return %s", calc_string)
    return tonumber(loadstring(script)())
end

--[[
---> 获取最小公约数
--]]
function _M.get_common_divisor(num1, num2)
    local min = math.min(num1, num2)
    local max = math.max(num1, num2)

    if (num1 == 0 or num2 == 0) then
      return max
    end

    local result = 1
    for i=min, 1, -1 do
      if (min % i == 0 and max % i == 0) then
        result = i
        break
      end
    end

    return result
end

--[[
---> 实现权重概率分配，支持数字比模式(支持2位小数)和百分比模式(不支持小数，最后一个元素多退少补)
---> @param    Array    arr    数组，参数类型[Object,Object,Object……]
---> @return   Array           返回一个随机元素，概率为其weight/所有weight之和，参数类型Object
--]]
function _M.weight_rand(array)    
    --参数array元素必须含有weight属性，参考如下所示
    --local array=[{name:'1',weight:1.5},{name:'2',weight:2.5},{name:'3',weight:3.5}];
    --local array=[{name:'1',weight:'15%'},{name:'2',weight:'25%'},{name:'3',weight:'35%'}];
    --求出最大公约数以计算缩小倍数，perMode为百分比模式
    local per
    local maxNum = 0
    local perMode = false

    --使用clone元素对象拷贝仍然会造成浪费，但是使用权重数组对应关系更省内存
    local weight_array = {}
    for i=1,#array do
        if (array[i].weight) then
            if s_find(tostring(array[i].weight), '%%') then
                per = m_floor(s_gsub(tostring(array[i].weight), '%%', ''))
                perMode = true
            else
                local int,float = math.modf(array[i].weight)
                -- 算出小数位长度(or 为没有小数的情况)
                local float_len = #tostring(_M.round(float)) - 2
                if float_len < 0 then 
                    float_len = 0
                end
                local convert_multiple = math.pow(10, float_len)  
                per = m_floor(array[i].weight * convert_multiple)
            end
        else
            per = 0
        end

        weight_array[i] = per
        maxNum = _M.get_common_divisor(maxNum, per)
    end

    -- ngx.log(ngx.ERR, per)
    -- ngx.log(ngx.ERR, maxNum)
    -- do return array[1] end
    --数字比模式，3:5:7，其组成[0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2]
    --百分比模式，元素所占百分比为15%，25%，35%
    local index = {}
    local total = 0
    local len = 0
    if perMode then
        for i=1,#array do
            --len表示存储array下标的数据块长度，已优化至最小整数形式减小索引数组的长度
            len = weight_array[i]
            for j=1,len do
                --超过100%跳出，后面的舍弃
                if (total >= 100) then
                  break
                end
                t_insert(index, i)
                total=total+1
            end
        end
        --使用最后一个元素补齐100%
        while (total < 100) do
            t_insert(index, #array - 1)
            total=total+1
        end
    else
      for i=1,#array do
        --len表示存储array下标的数据块长度，已优化至最小整数形式减小索引数组的长度
        len = weight_array[i] / maxNum
        for j=1,len do
            t_insert(index, i)
        end

        total = total + len
      end
    end

    --随机数值，其值为0-11的整数，数据块根据权重分块
    local rand = m_ceil(_M.random() * total)
    return array[index[rand]]
end

--[[
---> 平衡交换
----> @to_grow 需要增长的值
----> @to_reduce 需要减少的值
----> @value 平衡值
--]]
function _M.balance_exchange(to_grow, to_reduce, value)
    to_grow = to_grow + value
    to_reduce = to_reduce - value

    return to_grow, to_reduce
end

--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M