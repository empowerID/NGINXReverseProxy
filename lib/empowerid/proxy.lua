local cjson_module = require "cjson.safe"
local http = require"resty.http"
local config_module = require"empowerid.config"

local SHARED_DICT_NAME = "empowerid_proxy_config"
local API_CONFIG_KEY = "empowerid_API_CONFIG"

-- here we story all configurations, state, whatever
-- we can very simple refactor this singleton into set of handler
-- if it will be required
local handler = {}

-- only for debug perpose, don't use in production!
local function tprint (tbl, indent)
    if not indent then indent = 0 end
    local toprint = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if (type(k) == "number") then
            toprint = toprint .. "[" .. k .. "] = "
        elseif (type(k) == "string") then
            toprint = toprint  .. k ..  "= "
        end
        if (type(v) == "number") then
            toprint = toprint .. v .. ",\r\n"
        elseif (type(v) == "string") then
            toprint = toprint .. "\"" .. v .. "\",\r\n"
        elseif (type(v) == "table") then
            toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
        else
            toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent-2) .. "}"
    return toprint
end

local function try_get_api_token(opts)
    local body = {
        client_id = opts.client_id,
        client_secret = opts.client_secret,
        grant_type = "password",
    }

    body = ngx.encode_args(body)
    print("try_request_urlencoded, body: ", body, " uri: ", opts.token_endpoint)

    local httpc = http.new()
    local res, err = httpc:request_uri(opts.token_endpoint, {
        method = "POST",
        body = body,
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = "Basic " .. opts.token_endpoint_basic_auth,
            ["X-EmpowerID-API-Key"] = opts.empowerid_api_key
        }
    })

    if not res then
        error(err)
    end
    print(res.body)

    local cjson = cjson_module.new()
    local body, err = cjson.decode(res.body)
    if not body then
        error(err)
    end
    print(tprint(body))
    return body.access_token
end

local function try_get_results(access_token, body)
    print("try_get_results, body: ", body)
    local opts = handler.opts
    local httpc = http.new()
    local res, err = httpc:request_uri(opts.get_results_endpoint, {
        method = "POST",
        body = body,
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. access_token,
            ["X-EmpowerID-API-Key"] = opts.empowerid_api_key,
        }
    })
    if not res then
        error(err)
    end
    print(res.body)

    local cjson = cjson_module.new()
    local body, err = cjson.decode(res.body)
    if not body then
        error(err)
    end
    --print(tprint(body))
    res.body = body
    return res
end

local function main_refresh_config()
    local opts = handler.opts

    local access_token = try_get_api_token(opts)

    local res = try_get_results(access_token,
    "{\"storedProcedure\" : \"ReverseProxy_ProtectedApplicationResource_SetWamShortIDs\", \"parameters\" : \"{}\"}")

    local res = try_get_results(access_token,
        "{\"storedProcedure\" : \"ReverseProxy_GetServiceProviders\", \"parameters\" : \"{}\"}")

    local config = config_module.new()
    local serviceProviderIDs = config(res.body.Results, opts.service_providers_guids)
    print(serviceProviderIDs)

    local res = try_get_results(access_token,
        "{\"storedProcedure\" : \"ReverseProxy_GetApplications\", \"parameters\" : \"{\\\"inputParams\\\":\\\""
        .. serviceProviderIDs .."\\\"}\"}")

    local protectedApplicationResourceID = config(res.body.Results)
    print(protectedApplicationResourceID)

    if protectedApplicationResourceID then
        local res = try_get_results(access_token,
            "{\"storedProcedure\" : \"ReverseProxy_GetPages\", \"parameters\" : \"{\\\"inputParams\\\":\\\""
            .. protectedApplicationResourceID .."\\\"}\"}")
        config(res.body.Results)
    else
        config(nil)
    end

    local res = try_get_results(access_token,
        "{\"storedProcedure\" : \"ReverseProxy_GetRBACRights\", \"parameters\" : \"{}\"}")
    local api_config = config(res.body.Results)

    --print(tprint(api_config))
    local cjson = cjson_module.new()
    local api_config_json, err = cjson.encode(api_config)
    if not api_config_json then
        error(err)
    end

    if handler.api_config_json == api_config_json then
        return
    end

    handler.api_config_json = api_config_json
    handler.api_config = api_config

    local shared_config = ngx.shared[SHARED_DICT_NAME]
    assert(shared_config:set(API_CONFIG_KEY, api_config_json))
    assert(shared_config:set("access_token", access_token))
end

local function regular_refresh_config()
    local shared_config = ngx.shared[SHARED_DICT_NAME]
    local api_config_json = shared_config:get(API_CONFIG_KEY)
    if not api_config_json then
        ngx.log(ngx.ALERT, "API config is not ready yet")
        return
    end

    if handler.api_config_json == api_config_json then
        return
    end

    local cjson = cjson_module.new()
    local api_config, err = cjson.decode(api_config_json)
    if not api_config then
        ngx.log(ngx.ERR, err)
        handler.api_config_json = nil
        handler.api_config = nil
        return
    end
    handler.api_config_json = api_config_json
    handler.api_config = api_config
    print"config updated"
    return true
end

local function regular_refresh_timer(premature)
    if premature then
        return
    end
    print("regular_refresh_timer, ngx.worker.id(): ", ngx.worker.id())
    local ok, err = xpcall( regular_refresh_config, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end

local function regular_bootstrap_timer(premature)
    if premature then
        return
    end
    print("regular_bootstrap_timer, ngx.worker.id(): ", ngx.worker.id())
    local ok, err = xpcall( regular_refresh_config, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end

    if err then
        print"config obtained, switch to regular refresh"
        assert(ngx.timer.every(handler.opts.refresh_timeout, regular_refresh_timer))
        return
    end

    -- refresh config every second until ready
    assert(ngx.timer.at(2, regular_bootstrap_timer))
end


local function main_refresh_timer(premature)
    if premature then
        return
    end
    print("main_refresh_timer , ngx.worker.id(): ",ngx.worker.id())
    local ok, err = xpcall( main_refresh_config, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end

local function main_bootstrap_timer(premature)
    if premature then
        return
    end
    print("main_bootstrap_timer, ngx.worker.id(): ", ngx.worker.id())
    local ok, err = xpcall( main_refresh_config, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end

    assert(ngx.timer.every(handler.opts.refresh_timeout, main_refresh_timer))
end

-- we don't need to catch error here
-- nginx doesn't start in case of fatal error during this phase
local function init_worker_handler(opts)
    -- TODO validate opts
    assert(opts.service_providers_guids)
    if type(opts.service_providers_guids) == "string" then
        opts.service_providers_guids = { [opts.service_providers_guids] = true }
    elseif type(opts.service_providers_guids) ~= "table" then
        error("Bad service_providers_guids type: " .. type(opts.service_providers_guids) .. " should be string or table")
    end

    -- TODO set defaults
    opts.refresh_timeout = opts.refresh_timeout or 60 --seconds

    -- we got array of GUIDs, for fast access we need a dictionary, convert
    local guids = opts.service_providers_guids
    local t = {}
    for i =1, #guids do
        t[guids[i]] = true
    end
    opts.service_providers_guids = t

    handler.opts = opts

    if ngx.worker.id() == 0 then
        ngx.timer.at(0, main_bootstrap_timer)
    else
        ngx.timer.at(2, regular_bootstrap_timer)
    end
end

local function fatalError(...)
    local t  = {...}
    ngx.log(ngx.ERR, table.concat(t))
    ngx.exit(502)
end

local function doliveAbacCheck(protectedPageGuid, personName)
    print("doliveAbacCheck, protectedPageGuid: ", protectedPageGuid, " personName: ", personName )
    local opts = handler.opts

    local shared_config = ngx.shared[SHARED_DICT_NAME]
    local access_token = shared_config:get("access_token")

    local httpc = http.new()
    local body = "{ \"person\":\"" .. personName .. "\", \"page\":\"" .. protectedPageGuid .. "\" }"
    local res, err = httpc:request_uri(opts.hasaccesstopage_endpoint, {
        method = "POST",
        body = body,
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. access_token,
            ["X-EmpowerID-API-Key"] = opts.empowerid_api_key,
        }
    })
    if not res then
        error(err)
    end
    print(tprint(res))

    local body = res.body
    if body == "true" then
        return
    end

    ngx.exit(403) -- forbidden
end

local function authenticate()
    local opts = handler.opts
    local openidc_opts = {
        redirect_uri_path = opts.redirect_uri_path,
        discovery = opts.discovery,
        client_id = opts.client_id,
        client_secret = opts.client_secret,
        ssl_verify = "no",
        logout_path = "/logout", -- TODO
        --redirect_after_logout_uri = "/",
    }
    local res, err = require("resty.openidc").authenticate(openidc_opts)

    if err then
        return fatalError(err)
    end

    if res.id_token and res.id_token.attrib and res.id_token.attrib.username  and res.id_token.attrib.ReverseProxyPersonID then
        ngx.req.set_header("X-Empowerid-Username", res.id_token.attrib.ReverseProxyPersonID)
        ngx.req.set_header("EID-USER", res.id_token.attrib.ReverseProxyPersonID)
        return res.id_token.attrib.username, res.id_token.attrib.ReverseProxyPersonID
    end

    fatalError("Missed id_token.attrib.username: ", tprint(res))
end

local function access_handler()
    -- check for patterns to skip the authorization
    local page_skip_regexp = handler.opts.page_skip_regexp
    local uri = ngx.var.uri
    if page_skip_regexp and #page_skip_regexp > 0 then
        if ngx.re.match(uri, page_skip_regexp) then
            return
        end
    end

    local api_config = handler.api_config
    if not api_config then
        return fatalError("No configuration ready yet")
    end

    local scheme_host = ngx.var.scheme .. "://" .. ngx.var.host
    local config = config_module.open(api_config, scheme_host)
    if not config then
        -- TODO what to do if config for this host doesn't exists?
        --return -- allow
        return fatalError("No configuration for ", scheme_host) -- deny
    end

    if not config:doesProtectedPathsExists() then
        if config:allowNoAuthForNonProtectedPaths() then
            return
        end
        authenticate()
        return
    end

    local protectedPageId, protectedPageGuid, mustDoLiveCheck = config:isProtectedPath(uri)
    print("protectedPageId: ", protectedPageId)
    print("protectedPageGuid: ", protectedPageGuid)
    print("mustDoLiveCheck: ", mustDoLiveCheck)
    if not protectedPageGuid then
        if config:allowNoAuthForNonProtectedPaths() then
            return
        end
        authenticate()
        return
    end

    -- protected path

    local personName, personId = authenticate()
    print("personName: ", personName)
    print("personId: ", personId)

    if mustDoLiveCheck then
        return doliveAbacCheck(protectedPageGuid, personName)
    end

    if config_module.checkStaticAbacRights(api_config, protectedPageId, personId) then
        return
    end
    ngx.exit(403) -- forbidden
end

return function(...)
    local phase = ngx.get_phase()

    -- most often called phase first
    if phase == "access" then
        local ok, err = xpcall(access_handler, debug.traceback)
        if ok then
            return
        end

        ngx.log(ngx.ERR, err)
        ngx.header['ngx_error'] = err
        return ngx.exit(502)
    end
    if phase == "init_worker" then
        return init_worker_handler(...)
    end

    ngx.log(ngx.ERR, "module called on unsupported phase: ", phase)
end
