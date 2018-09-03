local ipairs = ipairs
local type = type
local tostring = tostring
local t_insert = table.insert
local s_format = string.format

local c_json = require("app.utils.json")
local u_string = require("app.utils.string")
local u_time = require("app.utils.time")
local l_uuid = require("app.lib.uuid")

local r_plugin = require("app.model.repository.plugin_repo")

-- build common apis
return function(conf, store, plugin)
    local API = { }
    
    local current_repo = r_plugin(conf, store, plugin)
    local current_cache = current_repo._adapter.current_cache
    local current_db = current_repo._adapter.current_db

    API["/" .. plugin .. "/enable"] = {
        POST = function()
            return function(req, res, next)
                local enable = req.body.enable
                if enable == "1" then enable = true else enable = false end

                local plugin_enable = "0"
                if enable then plugin_enable = "1" end
                local update_result = current_repo:update_enable(plugin, plugin_enable)

                if update_result then
                    local success, _, _ = current_cache:set(plugin .. ".enable", enable)
                    if success then
                        return res:json({
                            success = true ,
                            msg = (enable == true and "succeed to enable plugin" or "succeed to disable plugin")
                        })
                    end
                end

                res:json({
                    success = false,
                    msg = (enable == true and "failed to enable plugin" or "failed to disable plugin")
                })
            end
        end
    }

    -- fetch config from store
    API["/" .. plugin .. "/fetch_config"] = {
        GET = function()
            return function(req, res, next)
                local success, data =  current_repo:compose_plugin_data(plugin)
                if success then
                    return res:json({
                        success = true,
                        msg = "succeed to fetch config from store",
                        data = data
                    })
                else
                    ngx.log(ngx.ERR, "error to fetch plugin[" .. plugin .. "] config from store")
                    return res:json({
                        success = false,
                        msg = "error to fetch config from store"
                    })
                end
            end
        end
    }

    -- get config in Orange's node now
    API["/" .. plugin .. "/config"] = {
        GET = function()
            return function(req, res, next)
                local enable = current_cache:get(plugin .. ".enable") or false
                local meta = current_cache:get_json(plugin .. ".meta") or {}

                local selectors = {}
                if meta and meta.selectors and type(meta.selectors)=="table" then
                    for i, sid in ipairs(meta.selectors) do
                        local selector = {}
                        local cache_selectors = current_cache:get_json(plugin .. ".selectors") or {}
                        for j, selector_detail in pairs(cache_selectors) do
                            if j == sid then
                                selector = selector_detail
                                if selector_detail.rules and type(selector_detail.rules) == "table" then
                                    local rule_ids = selector_detail.rules
                                    local cache_rules = current_cache:get_json(plugin .. ".selector." .. sid .. ".rules") or {}
                                    local rules = {}
                                    for m, rule_id in ipairs(rule_ids) do
                                        for n, rule in ipairs(cache_rules) do
                                            if rule_id == rule.id then
                                                t_insert(rules, rule)
                                            end
                                        end
                                    end
                                    selector.rules = rules
                                else
                                    selector.rules = {}
                                end
                            end
                        end
                        t_insert(selectors, selector)
                    end
                end

                return res:json({
                    success = true,
                    msg = "succeed to get configuration in this node",
                    data = {
                        enable = enable,
                        selectors = selectors
                    }
                })
            end
        end
    }

    -- update the local cache to data stored in db
    API["/" .. plugin .. "/sync"] = {
        POST = function()
            return function(req, res, next)
                local load_success = current_repo:load_data_by_db(plugin)
                if load_success then
                    return res:json({
                        success = true,
                        msg = "succeed to load config from store"
                    })
                else
                    ngx.log(ngx.ERR, "error to load plugin[" .. plugin .. "] config from store")
                    return res:json({
                        success = false,
                        msg = "error to load config from store"
                    })
                end
            end
        end
    }

    API["/" .. plugin .. "/selectors/:id/rules"] = {
        POST = function() -- create
            return function(req, res, next)
                local selector_id = req.params.id
                local selector = current_repo:get_selector(plugin, selector_id)
                if not selector or not selector.value then
                    return res:json({
                        success = false,
                        msg = "selector not found when creating rule"
                    })
                end

                local current_selector = c_json.decode(selector.value)
                if not current_selector then
                    return res:json({
                        success = false,
                        msg = "selector could not be decoded when creating rule"
                    })
                end

                local rule = req.body.rule
                rule = c_json.decode(rule)
                rule.id = l_uuid()
                rule.time = u_time.now()

                -- 插入到mysql
                local insert_result = current_repo:create_rule(plugin, rule)

                -- 插入成功
                if insert_result then
                    -- update selector
                    current_selector.rules = current_selector.rules or {}
                    t_insert(current_selector.rules, rule.id)
                    local update_selector_result = current_repo:update_selector(plugin, current_selector)
                    if not update_selector_result then
                        return res:json({
                            success = false,
                            msg = "update selector error when creating rule"
                        })
                    end

                    -- update local selectors
                    local update_local_selectors_result = current_repo:update_local_selectors(plugin)
                    if not update_local_selectors_result then
                        return res:json({
                            success = false,
                            msg = "error to update local selectors when creating rule"
                        })
                    end

                    local update_local_selector_rules_result = current_repo:update_local_selector_rules(plugin, selector_id)
                    if not update_local_selector_rules_result then
                        return res:json({
                            success = false,
                            msg = "error to update local rules of selector when creating rule"
                        })
                    end
                else
                    return res:json({
                        success = false,
                        msg = "fail to create rule"
                    })
                end

                res:json({
                    success = true,
                    msg = "succeed to create rule"
                })
            end
        end,

        GET = function()
            return function(req, res, next)
                local selector_id = req.params.id

                local rules = current_cache:get_json(plugin .. ".selector." .. selector_id .. ".rules") or {}
                res:json({
                    success = true,
                    data = {
                        rules = rules
                    }
                })
            end
        end,

        PUT = function() -- modify
            return function(req, res, next)
                local selector_id = req.params.id
                local rule = req.body.rule
                rule = c_json.decode(rule)
                rule.time = u_time.now()

                local update_result = current_repo:update_rule(plugin, rule)

                if update_result then
                    local old_rules = current_cache:get_json(plugin .. ".selector." .. selector_id .. ".rules") or {}
                    local new_rules = {}
                    for _, v in ipairs(old_rules) do
                        if v.id == rule.id then
                            rule.time = u_time.now()
                            t_insert(new_rules, rule)
                        else
                            t_insert(new_rules, v)
                        end
                    end

                    local success, err, forcible = current_cache:set_json(plugin .. ".selector." .. selector_id .. ".rules", new_rules)
                    if err or forcible then
                        ngx.log(ngx.ERR, "update local rules error when modifing:", err, ":", forcible)
                        return res:json({
                            success = false,
                            msg = "update local rules error when modifing"
                        })
                    end

                    return res:json({
                        success = success,
                        msg = success and "ok" or "failed"
                    })
                end

                res:json({
                    success = false,
                    msg = "update rule to db error"
                })
            end
        end,

        DELETE = function()
            return function(req, res, next)
                local selector_id = req.params.id
                local selector = current_repo:get_selector(plugin, selector_id)
                if not selector or not selector.value then
                    return res:json({
                        success = false,
                        msg = "selector not found when deleting rule"
                    })
                end

                local current_selector = c_json.decode(selector.value)
                if not current_selector then
                    return res:json({
                        success = false,
                        msg = "selector could not be decoded when deleting rule"
                    })
                end

                local rule_id = tostring(req.body.rule_id)
                if not rule_id or rule_id == "" then
                    return res:json({
                        success = false,
                        msg = "error param: rule id shoule not be null."
                    })
                end

                local delete_result = current_repo._adapter.current_db.delete({
                    sql = "delete from " .. plugin .. " where `key`=? and `type`=?",
                    params = { rule_id, "rule"}
                })

                if delete_result then
                    -- update selector
                    local old_rules_ids = current_selector.rules or {}
                    local new_rules_ids = {}
                    for _, orid in ipairs(old_rules_ids) do
                        if orid ~= rule_id then
                            t_insert(new_rules_ids, orid)
                        end
                    end
                    current_selector.rules = new_rules_ids

                    local update_selector_result = current_repo:update_selector(plugin, current_selector)
                    if not update_selector_result then
                        return res:json({
                            success = false,
                            msg = "update selector error when deleting rule"
                        })
                    end

                    -- update local selectors
                    local update_local_selectors_result = current_repo:update_local_selectors(plugin)
                    if not update_local_selectors_result then
                        return res:json({
                            success = false,
                            msg = "error to update local selectors when deleting rule"
                        })
                    end

                    -- update local rules of selector
                    local update_local_selector_rules_result = current_repo:update_local_selector_rules(plugin, selector_id)
                    if not update_local_selector_rules_result then
                        return res:json({
                            success = false,
                            msg = "error to update local rules of selector when creating rule"
                        })
                    end
                else
                    res:json({
                        success = false,
                        msg = "delete rule from db error"
                    })
                end

                res:json({
                    success = true,
                    msg = "succeed to delete rule"
                })
            end
        end
    }

    -- update rules order
    API["/" .. plugin .. "/selectors/:id/rules/order"] = {
        PUT = function()
            return function(req, res, next)
                local selector_id = req.params.id

                local new_order = req.body.order
                if not new_order or new_order == "" then
                    return res:json({
                        success = false,
                        msg = "error params"
                    })
                end

                local tmp = u_string.split(new_order, ",")
                local rules = {}
                if tmp and type(tmp) == "table" and #tmp > 0 then
                    for _, t in ipairs(tmp) do
                        t_insert(rules, t)
                    end
                end

                local update_selector_result, update_local_selectors_result, update_local_selector_rules_result
                local selector = current_repo:get_selector(plugin, selector_id)
                if not selector or not selector.value then
                    ngx.log(ngx.ERR, "error to find selector when resorting rules of it")
                    return res:json({
                        success = true,
                        msg = "error to find selector when resorting rules of it"
                    })
                else
                    local new_selector = c_json.decode(selector.value) or {}
                    new_selector.rules = rules
                    update_selector_result = current_repo:update_selector(plugin, new_selector)
                    if update_selector_result then
                        update_local_selectors_result = current_repo:update_local_selectors(plugin)
                    end
                end

                if update_selector_result and update_local_selectors_result then
                    update_local_selector_rules_result = current_repo:update_local_selector_rules(plugin, selector_id)
                    if update_local_selector_rules_result then
                        return res:json({
                            success = true,
                            msg = "succeed to resort rules"
                        })
                    end
                end

                ngx.log(ngx.ERR, "error to update local data when resorting rules, update_selector_result:", update_selector_result, " update_local_selectors_result:", update_local_selectors_result, " update_local_selector_rules_result:", update_local_selector_rules_result)
                res:json({
                    success = false,
                    msg = "fail to resort rules"
                })
            end
        end
    }

    API["/" .. plugin .. "/selectors"] = {
        GET = function() -- get selectors
            return function(req, res, next)
                res:json({
                    success = true,
                    data = {
                        enable = current_cache:get_bool(plugin .. ".enable"),
                        meta = current_cache:get_json(plugin .. ".meta"),
                        selectors = current_cache:get_json(plugin .. ".selectors")
                    }
                })
            end
        end,

        DELETE = function() -- delete selector
            --- 1) delete selector
            --- 2) delete rules of it
            --- 3) update meta
            --- 4) update local meta & selectors
            return function(req, res, next)

                local selector_id = tostring(req.body.selector_id)
                if not selector_id or selector_id == "" then
                    return res:json({
                        success = false,
                        msg = "error param: selector id shoule not be null."
                    })
                end

                -- get selector
                local selector = current_repo:get_selector(plugin, selector_id)
                if not selector or not selector.value then
                    return res:json({
                        success = false,
                        msg = "error: can not find selector#" .. selector_id
                    })
                end

                -- delete rules of it
                local to_del_selector = c_json.decode(selector.value)
                if not to_del_selector then
                    return res:json({
                        success = false,
                        msg = "error: decode selector#" .. selector_id .. " failed"
                    })
                end

                local to_del_rules_ids = to_del_selector.rules or {}
                local d_result = current_repo:delete_rules_of_selector(plugin, to_del_rules_ids)
                ngx.log(ngx.ERR, "delete rules of selector:", d_result)

                -- update meta
                local meta = current_repo:get_meta(plugin)
                local current_meta = c_json.decode(meta.value)
                if not meta or not current_meta then
                   return res:json({
                        success = false,
                        msg = "error: can not find meta"
                    })
                end

                local current_selectors_ids = current_meta.selectors or {}
                local new_selectors_ids = {}
                for _, v in ipairs(current_selectors_ids) do
                    if  selector_id ~= v then
                        t_insert(new_selectors_ids, v)
                    end
                end
                current_meta.selectors = new_selectors_ids

                local update_meta_result = current_repo:update_meta(plugin, current_meta)
                if not update_meta_result then
                    return res:json({
                        success = false,
                        msg = "error: update meta error"
                    })
                end

                -- delete the very selector
                local delete_selector_result = current_repo:delete_selector(plugin, selector_id)
                if not delete_selector_result then
                    return res:json({
                        success = false,
                        msg = "error: delete the very selector error"
                    })
                end

                -- update local meta & selectors
                local update_local_meta_result = current_repo:update_local_meta(plugin)
                local update_local_selectors_result = current_repo:update_local_selectors(plugin)
                if update_local_meta_result and update_local_selectors_result then
                    return res:json({
                        success = true,
                        msg = "succeed to delete selector"
                    })
                else
                    ngx.log(ngx.ERR, "error to delete selector, update_meta:", update_local_meta_result, " update_selectors:", update_local_selectors_result)
                    return res:json({
                        success = false,
                        msg = "error to udpate local data when deleting selector"
                    })
                end
            end
        end,

        POST = function() -- create a selector
            return function(req, res)
                local selector = req.body.selector
                selector = c_json.decode(selector)
                selector.id = l_uuid()
                selector.time = u_time.now()

                -- create selector
                local insert_result = current_repo:create_selector(plugin, selector)

                -- update meta
                local meta = current_repo:get_meta(plugin)
                local current_meta = c_json.decode(meta and meta.value or "{}")
                if not meta or not current_meta then
                   return res:json({
                        success = false,
                        msg = "error: can not find meta when creating selector"
                    })
                end
                current_meta.selectors = current_meta.selectors or {}
                t_insert(current_meta.selectors, selector.id)
                local update_meta_result = current_repo:update_meta(plugin, current_meta)
                if not update_meta_result then
                    return res:json({
                        success = false,
                        msg = "error: update meta error when creating selector"
                    })
                end

                -- update local meta & selectors
                if insert_result then
                    local update_local_meta_result = current_repo:update_local_meta(plugin)
                    local update_local_selectors_result = current_repo:update_local_selectors(plugin)
                    if update_local_meta_result and update_local_selectors_result then
                        return res:json({
                            success = true,
                            msg = "succeed to create selector"
                        })
                    else
                        ngx.log(ngx.ERR, "error to create selector, update_meta:", update_local_meta_result, " update_selectors:", update_local_selectors_result)
                        return res:json({
                            success = false,
                            msg = "error to udpate local data when creating selector"
                        })
                    end
                else
                    return res:json({
                        success = false,
                        msg = "error to save data when creating selector"
                    })
                end
            end
        end,

        PUT = function() -- update
            return function(req, res, next)
                local selector = req.body.selector
                selector = c_json.decode(selector)
                selector.time = u_time.now()

                -- 更新selector
                local update_selector_result = current_repo:update_selector(plugin, selector)
                if update_selector_result then
                    local update_local_selectors_result = current_repo:update_local_selectors(plugin)
                    if not update_local_selectors_result then
                        return res:json({
                            success = false,
                            msg = "error to local selectors when updating selector"
                        })
                    end
                else
                    return res:json({
                        success = false,
                        msg = "error to update selector"
                    })
                end

                return res:json({
                    success = true,
                    msg = "succeed to update selector"
                })
            end
        end
    }

    -- update selectors order
    API["/" .. plugin .. "/selectors/order"] = {
        PUT = function()
            return function(req, res, next)
                local new_order = req.body.order
                if not new_order or new_order == "" then
                    return res:json({
                        success = false,
                        msg = "error params"
                    })
                end

                local tmp = u_string.split(new_order, ",")
                local selectors = {}
                if tmp and type(tmp) == "table" and #tmp > 0 then
                    for _, t in ipairs(tmp) do
                        t_insert(selectors, t)
                    end
                end

                local update_meta_result, update_local_meta_result
                local meta = current_repo:get_meta(plugin)
                if not meta or not meta.value then
                    ngx.log(ngx.ERR, "error to find meta when resorting selectors")
                    return res:json({
                        success = true,
                        msg = "error to find meta when resorting selectors"
                    })
                else
                    local new_meta = c_json.decode(meta.value) or {}
                    new_meta.selectors = selectors
                    update_meta_result = current_repo:update_meta(plugin, new_meta)
                    if update_meta_result then
                        update_local_meta_result = current_repo:update_local_meta(plugin)
                    end
                end

                if update_meta_result and update_local_meta_result then
                    res:json({
                        success = true,
                        msg = "succeed to resort selectors"
                    })
                else
                    ngx.log(ngx.ERR, "error to update local meta when resorting selectors, update_meta_result:", update_meta_result, " update_local_meta_result:", update_local_meta_result)
                    res:json({
                        success = false,
                        msg = "fail to resort selectors"
                    })
                end
            end
        end
    }

    return API
end