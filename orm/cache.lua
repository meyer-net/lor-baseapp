local error = error
local r_lrucache = require "resty.lrucache"

local c, err = r_lrucache.new(200)  -- allow up to 200 items in the cache
if not c then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return c
