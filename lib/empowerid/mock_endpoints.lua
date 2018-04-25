local cjson_module = require"cjson"

local _M = {}

-- metadata - should be in sycn with empowerid/config.lua
local SP_ID = 1
local SP_GUID = 2
local SP_AssertionConsumerURL = 6
local SP_FIELDS = 7

local APP_ID = 1
local APP_ServiceProviderID = 3
local APP_AllowNoAuthForNonProtectedPaths = 6
local APP_FIELDS = 9

local PG_ID = 1
local PG_AppID = 2
local PG_MatchingPath = 3     -- should be ignored
local PG_MatchingMVCPath = 4
local PG_MatchingPattern = 5
local PG_ProtectedApplicationResourceGUID = 6
local PG_ABACCheck = 7
local PG_FIELDS = 7

local ABAC_PAGE_ID = 1
local ABAC_PERSON_ID = 2
local ABAC_FIELDS = 2

local cjson_null = cjson_module.new().null


-- here we load data model
-- fields:
--   SP, APP, PG - service_providers, applications, pages
--   RBACR - role based access control rights
local model

_M.get_token_endpoint = function()
    assert(model)
    assert(ngx.get_phase() == "content")

    if ngx.req.get_method() ~= "POST" then
        return ngx.exit(400)
    end

    assert(ngx.var.http_authorization == "Basic " .. model.basic_auth)
    assert(ngx.var.http_content_type == "application/x-www-form-urlencoded")
    assert(ngx.var.http_x_empowerid_api_key == model.X_EmpowerID_API_Key)

    ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
    if not args then
        error("failed to get post args: ", err)
    end
    assert(args.client_id == model.client_id)
    assert(args.client_secret == model.client_secret)
    assert(args.grant_type == "password")

    ngx.header["Content-Type"] = "application/json"
    local cjson = cjson_module.new()
    ngx.say(cjson.encode{
        access_token = model.access_token
    })
end

local function split_by(text, sep)
    local fields =  {}
    local pattern = string.format("([^%s]+)", sep)
    text:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local get_results_handlers = {
    ReverseProxy_GetServiceProviders = function()
        if #model.SP > 0 then
            return {
                Errors = cjson_null,
                Results = model.SP
            }
        end
        return {
            Error = "Empty model"
        }
    end,

    ReverseProxy_GetApplications = function(parameters)
        local input_parameters = parameters:match("[%d,]+")
        if not input_parameters then
            -- TODO should we return all?!
            return
        end
        local sp_ids = split_by(input_parameters, ",")
        local results = {}
        local app = model.APP
        for i = 1, #sp_ids do
            for k = 1, #app do
                print(sp_ids[i])
                print(app[k][APP_ServiceProviderID])
                if tonumber(sp_ids[i]) == app[k][APP_ServiceProviderID] then
                    results[#results + 1] = app[k]
                    break
                end
            end
        end
        if #results > 0 then
            return {
                Errors = cjson_null,
                Results = results
            }
        end
        return {
            Error = "Not found"
        }
    end,

    ReverseProxy_GetPages = function(parameters)
        local input_parameters = parameters:match("[%d,]+")
        if not input_parameters then
            -- TODO should we return all?!
            return
        end
        local app_ids = split_by(input_parameters, ",")
        local results = {}
        local pg = model.PG
        for i = 1, #app_ids do
            for k = 1, #pg do
                if tonumber(app_ids[i]) == pg[k][PG_AppID] then
                    results[#results + 1] = pg[k]
                    break
                end
            end
        end
        if #results > 0 then
            return {
                Errors = cjson_null,
                Results = results
            }
        end
        return {
            Error = "Not found"
        }
    end,

    ReverseProxy_GetRBACRights = function()
        if #model.RBACR > 0 then
            return {
                Errors = cjson_null,
                Results = model.RBACR
            }
        end
        return {
            Error = "Empty model"
        }
    end,
}

_M.get_results_endpoint = function()
    assert(model)
    assert(ngx.get_phase() == "content")

    assert(ngx.var.http_authorization == "Bearer " .. model.access_token)
    assert(ngx.var.http_content_type == "application/json")
    assert(ngx.var.http_x_empowerid_api_key == model.X_EmpowerID_API_Key)

    local cjson = cjson_module.new()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    local body_table = cjson.decode(body)
    assert(body_table.storedProcedure)
    assert(body_table.parameters)

    local body = assert(get_results_handlers[body_table.storedProcedure](body_table.parameters))

    ngx.header["Content-Type"] = "application/json"
    local cjson = cjson_module.new()
    local resp_body = cjson.encode(body)
    ngx.say(resp_body)
end

local function find_page_by_guid(guid)
    local pg = model.PG
    for i = 1, #pg do
        if pg[i][PG_ProtectedApplicationResourceGUID] == guid then
            return pg[i][PG_ID]
        end
    end
end

_M.hasaccesstopage = function()
    assert(model)
    assert(ngx.get_phase() == "content")

    assert(ngx.var.http_authorization == "Bearer " .. model.access_token)
    assert(ngx.var.http_content_type == "application/json")
    assert(ngx.var.http_x_empowerid_api_key == model.X_EmpowerID_API_Key)

    local cjson = cjson_module.new()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    local body_table = cjson.decode(body)
    assert(body_table.person)
    assert(body_table.page)

    local person_name = body_table.person
    local page_guid = body_table.page

    -- we assume that only rights only for one user present within model
    local page_id = find_page_by_guid(page_guid)
    if not page_id then
        ngx.header["Content-Type"] = "text/plain; charset=utf-8"
        ngx.say("Page not found")
        return
    end

    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    local cjson = cjson_module.new()

    local rbacr = model.RBACR
    for i = 1, #rbacr do
        if rbacr[i][ABAC_PAGE_ID] == page_id then
            local resp_body = cjson.encode(true)
            ngx.say(resp_body)
            return
        end
    end
    local resp_body = cjson.encode(false)
    ngx.say(resp_body)
end

_M.new = function(m)
    -- basic fields verification
    assert(m.access_token)
    assert(m.basic_auth)
    assert(m.X_EmpowerID_API_Key)
    assert(m.client_id)
    assert(m.client_secret)
    assert(m.SP)
    assert(m.APP)
    assert(m.PG)
    assert(m.RBACR)

    model = m
end

return _M
