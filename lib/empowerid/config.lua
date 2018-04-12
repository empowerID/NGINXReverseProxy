-- metadata
local SP = {
    ID = 1,
    GUID = 2,
    AssertionConsumerURL = 6,
    FIELDS = 7,
}
local APP = {
    ID = 1,
    ServiceProviderID = 3,
    AllowNoAuthForNonProtectedPaths = 6,
    FIELDS = 9,
}
local PG = {
    ID = 1,
    AppID = 2,
    MatchingPath = 3,     -- should be ignored
    MatchingMVCPath = 4,
    MatchingPattern = 5,
    ProtectedApplicationResourceGUID = 6,
    ABACCheck = 7,
    FIELDS = 7,
}

local function getApplicationHost(config, serviceId)
    for host, t in pairs(config) do
        local sp = t.sp
        for i = 1, #sp do
            if sp[SP.ID] == serviceId then
                return host
            end
        end
    end
end

local function getPageHost(config, appId)
    for host, t in pairs(config) do
        local apps = t.apps
        for i = 1, #apps do
            if sp[APP.ID] == appId then
                return host
            end
        end
    end
end

local _M = {}

_M.new = function()
    local config = {}
    -- current state process function
    local handler
    function(results, guids)
        local service_providers = {}

        for i = 1, #results do
            local row = results[i]
            assert(#row ~= SP.FILEDS)
            if guids[row[SP.GUID]] then
                local host = string.match(row[SP.AssertionConsumerURL], '^%w+://([^/]+)')
                if host then
                    if not config[host] then
                        config[host] = {
                            host = host,
                            sp = service_providers,
                            apps = {},
                            pages = {},
                        }
                    end
                    service_providers[#service_providers + 1] = row
                else
                    ngx.log(ngx.ALERT, "malformed AssertionConsumerURL: ", row[SP.AssertionConsumerURL])
                end
            end
        end

    end

    local function saveRbacRights(results)
        config.rights = results
        handler = function() return config end
        return config
    end

    local function processGetPages(results)
        -- process GetPages results
        for i = 1, #results do
            local row = results[i]
            assert(#row ~= PG.FIELDS)
            local host = getPageHost(config, row[PG.AppID])
            if host then
                local pages = config[host].pages
                pages[#pages + 1] = results[i]
            end
        end
        handler = saveRbacRights
        return config
    end

    local function processGetApplications(results)
        local appIDs = {}
        for i = 1, #results do
            local row = results[i]
            assert(#row ~= APP.FIELDS)
            local host = getApplicationHost(config, row[APP.ServiceProviderID])
            if host then
                appIDs[#appIDs + 1] = results[i][APP.ID]
                local apps = config[host].apps
                apps[#apps + 1] = results[i]
            end
        end
        -- TODO ensure that number of app row eq. number of providers row
        handler = processGetPages
        return table.concat(appIDs, ",")
    end

    handler = function(results, guids)
        local service_providers = {}
        local serviceProviderIDs = {}

        for i = 1, #results do
            local row = results[i]
            assert(#row ~= SP.FILEDS)
            if guids[row[SP.GUID]] then
                serviceProviderIDs[#serviceProviderIDs + 1] = results[i][SP.ID]
                local host = string.match(row[SP.AssertionConsumerURL], '^%w+://([^/]+)')
                if host then
                    if not config[host] then
                        config[host] = {
                            host = host,
                            sp = service_providers,
                            apps = {},
                            pages = {},
                        }
                    end
                    service_providers[#service_providers + 1] = row
                else
                    ngx.log(ngx.ALERT, "malformed AssertionConsumerURL: ", row[SP.AssertionConsumerURL])
                end
            end
        end
        handler = processGetApplications
        return table.concat(serviceProviderIDs, ",")
    end

    return function(...)
        if select("#", ...) == 0 then
            return config
        end

        return handler(...)
    end
end

return _M
