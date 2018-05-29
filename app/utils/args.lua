--[[
---> 统一函数指针
--]]
local require = require
local tonumber = tonumber

local s_format = string.format
local s_sub = string.sub
local s_find = string.find
local t_concat = table.concat

local t_insert = table.insert

-----> 工具引用
-- local u_string = require("app.utils.string")
-- local u_object = require("app.utils.object")

-----> 外部引用
-- local c_json = require("cjson.safe")

-- 创建一个用于返回操作类的基准对象
local _M = { _VERSION = '0.01' }

---> 上下文 操作区域 --------------------------------------------------------------------------------------------

--升级版(能处理content-type=multipart/form-data的表单)：
local function explode ( _str,seperator )
    local pos, arr = 0, {}
        for st, sp in function() return s_find( _str, seperator, pos, true ) end do
            t_insert( arr, s_sub( _str, pos, st-1 ) )
            pos = sp + 1
        end
    t_insert( arr, s_sub( _str, pos ) )
    return arr
end

--[[
---> 获取ngx请求参数
--]]
function _M:get_from_ngx_req()
    local args = {}
    local file_args = {}
    local is_have_file_param = false
    local error_msg = ""
    local receive_headers = ngx.req.get_headers()
    local request_method = ngx.req.get_method()
    if "GET" == request_method then
        args = ngx.req.get_uri_args()
    elseif "POST" == request_method then
        ngx.req.read_body()

            --判断是否是multipart/form-data类型的表单
        if s_sub(receive_headers["content-type"] or "",1,20) == "multipart/form-data;" then   
            is_have_file_param = true
            content_type = receive_headers["content-type"]
            --body_data可是符合http协议的请求体，不是普通的字符串
            body_data = ngx.req.get_body_data()
            --请求体的size大于nginx配置里的client_body_buffer_size，则会导致请求体被缓冲到磁盘临时文件里，client_body_buffer_size默认是8k或者16k
            if not body_data then
                local datafile = ngx.req.get_body_file()
                if not datafile then
                    error_code = 1
                    error_msg = "no request body found"
                else
                    local fh, err = io.open(datafile, "r")
                    if not fh then
                        error_code = 2
                        error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err)
                    else
                        fh:seek("set")
                        body_data = fh:read("*a")
                        fh:close()
                        if body_data == "" then
                            error_code = 3
                            error_msg = "request body is empty"
                        end
                    end
                end
            end
            local new_body_data = {}
            --确保取到请求体的数据
            if not error_code then
                local boundary = "--" .. s_sub(receive_headers["content-type"],31)
                local body_data_table = explode(tostring(body_data),boundary)
                local first_string = table.remove(body_data_table,1)
                local last_string = table.remove(body_data_table)
                for i,v in ipairs(body_data_table) do
                    local start_pos,end_pos,capture,capture2 = s_find(v,'Content%-Disposition: form%-data; name="(.+)"; filename="(.*)"')
                    --普通参数
                    if not start_pos then
                        local t = explode(v,"\r\n\r\n")
                        local temp_param_name = s_sub(t[1],41,-2)
                        local temp_param_value = s_sub(t[2],1,-3)
                        args[temp_param_name] = temp_param_value
                    else
                    --文件类型的参数，capture是参数名称，capture2是文件名                            
                        file_args[capture] = capture2
                        t_insert(new_body_data,v)
                    end
                end
                t_insert(new_body_data,1,first_string)
                t_insert(new_body_data,last_string)
                --去掉app_key,app_secret等几个参数，把业务级别的参数传给内部的API
                body_data = t_concat(new_body_data,boundary)--body_data可是符合http协议的请求体，不是普通的字符串
            end
        else
            args = ngx.req.get_post_args()
        end
    end

    return args, error_msg, request_method
end


--[[
---> 
--]]
--function _M.()
    -- body
--end

-----------------------------------------------------------------------------------------------------------------

return _M