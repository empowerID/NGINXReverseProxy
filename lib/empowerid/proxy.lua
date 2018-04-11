local cjson_module = require "cjson.safe"
local http = require"resty.http"

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

local function try_request_urlencoded(url, opts)
    opts.body = ngx.encode_args(opts.body)
    opts.headers["Content-Type"] = "application/x-www-form-urlencoded"
    opts.headers["X-EmpowerID-API-Key"] = handler.opts.empowerid_api_key

    local httpc = http.new()
    local res, err = httpc:request_uri(url, opts)
    if not res then
        error(err)
    end
    --print(tprint(res))

    local cjson = cjson_module.new()
    local body, err = cjson.decode(res.body)
    if not body then
        error(err)
    end
    print(tprint(body))
    res.body = body
    return res
end

local function try_get_results(body, access_token)
    local opts = handler.opts
    local httpc = http.new()
    local res, err = httpc:request_uri(opts.get_results_endpoint, {
        method = "POST",
        body = body,
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. access_token,
            ["X-EmpowerID-API-Key"] = opts.empowerid_api_key,
        }
    })
    if not res then
        error(err)
    end
    --print(tprint(res))

    local cjson = cjson_module.new()
    local body, err = cjson.decode(res.body)
    if not body then
        error(err)
    end
    print(tprint(body))
    res.body = body
    return res
end

local function main_refresh_config()
    local opts = handler.opts

    local res = try_request_urlencoded(opts.token_endpoint, {
        method = "POST",
        body = {
            client_id = opts.client_id,
            client_secret = opts.client_id,
            grant_type = "password",
        },
        headers = {
            ["Authorization"] = "Basic " .. opts.token_endpoint_basic_auth,
        }
    })

    local access_token = res.body.access_token

    local res = try_get_results("{\"storedProcedure\" : \"ReverseProxy_GetServiceProviders\", \"parameters\" : \"{}\"}")
    local body = res.body

    local serviceProviderIDs = {}
    for i = 1, #body.Results do
        if opts.service_providers_guids[body.Results[i][1]] then
            serviceProviderIDs[#serviceProviderIDs + 1] = body.Results[i][1]
        end
    end
    serviceProviderIDs = table.concat(serviceProviderIDs, ",")
    print(serviceProviderIDs)

    local res = try_get_results(
        "{\"storedProcedure\" : \"ReverseProxy_GetApplications\", \"parameters\" : \"{\\\"inputParams\\\":\\\""
        .. serviceProviderIDs .."\\\"}\"}")
    local body = res.body

    local protectedApplicationResourceID = {}
    for i = 1, #body.Results do
        protectedApplicationResourceID[#protectedApplicationResourceID + 1] = body.Results[i][1]
    end
    protectedApplicationResourceID = table.concat(protectedApplicationResourceID, ",")
    print(protectedApplicationResourceID)

    local res = try_get_results(
        "{\"storedProcedure\" : \"ReverseProxy_GetPages\", \"parameters\" : \"{\\\"inputParams\\\":\\\""
        .. protectedApplicationResourceID .."\\\"}\"}")
    local body = res.body

    local res = try_get_results("{\"storedProcedure\" : \"ReverseProxy_GetRBACRights\", \"parameters\" : \"{}\"}")
    
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
end

local function regular_refresh_timer()
    --print"regular_refresh_timer"
    local ok, err = xpcall( function() regular_refresh_config() end, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end

local function main_refresh_timer()
    --print"main_refresh_timer"
    local ok, err = xpcall( function() main_refresh_config() end, debug.traceback)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end

local function main_bootstrap_timer()
    --print"main_bootstrap_timer"
    local ok, err = xpcall( function() main_refresh_config() end, debug.traceback)
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
    if type(opts.service_providers_guids) == string then
        opts.service_providers_guids = { [opts.service_providers_guids] = true }
    elseif type(opts.service_providers_guids) ~= table then
        error("Bad service_providers_guids type: " .. type(opts.service_providers_guids) .. " should be string or table")
    end

    -- TODO set defaults
    opts.refresh_timeout = opts.refresh_timeout or 300 --seconds

    handler.opts = opts

    if ngx.worker.id() == 0 then
        ngx.timer.at(0, main_bootstrap_timer)
    else
        ngx.timer.every(opts.refresh_timeout, regular_refresh_timer)
    end
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