local m_random = math.random
local m_modf = math.modf

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 数学 操作区域 ----------------------------------------------------------------------------------------------

--[[
-----> 返回随机数
--]]
function _M.random()
    return m_random(0, 1000)
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
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M