local error = error
local r_lrucache = require "resty.lrucache"

local s_format = string.format

local namespace = "app.store.orm.cache"

local c, err = r_lrucache.new(200)  -- allow up to 200 items in the cache
if not c then
    return error(s_format("[%s]Failed to create the cache: %s", namespace, err or "UnKnown"))
end

return c
