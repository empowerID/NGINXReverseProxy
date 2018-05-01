-- metadata
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

-- emulate ngx.re.find to be able to run standalone
if not ngx then
    ngx = {}
    ngx.re = {}
    ngx.re.find = function(subject, pattern, ignore) return subject:match(pattern) end
end

local function getApplicationHost(config, serviceId)
    for host, t in pairs(config) do
        if type(t) == "table" and t.sp[SP_ID] == serviceId  then
            return host
        end
    end
end

local function getPageHost(config, appId)
    for host, t in pairs(config) do
        if type(t) == "table" and t.app[APP_ID] == appId then
            return host
        end
    end
end

local function normalizeHost(host)
    if host:match(":%d+$") then
        return host
    end
    local isHttps = host:match("^(https)")
    if isHttps then
        return host .. ":443"
    end
    return host .. ":80"
end


local mt = {
    doesProtectedPathsExists = function(self)
        for k, v in pairs(self.pages) do
            return true
        end
        return false
    end,

    allowNoAuthForNonProtectedPaths = function(self)
        return self.app[APP_AllowNoAuthForNonProtectedPaths] == true or self.app[APP_AllowNoAuthForNonProtectedPaths] == "true"
    end,

    isProtectedPath = function(self, path)
        print("isProtectedPath: ", path)
        local pages = self.pages
        for id , row in pairs(pages) do
            print("page id: ", id)
            local prefix = row[PG_MatchingMVCPath]
            print("prefix: ", prefix)
            if type(prefix) == "string" and #prefix > 0 then
                if prefix:sub(1,1) ~= "/" then
                    prefix = "/" .. prefix
                end
                if path:sub(1, #prefix) == prefix then
                    return tonumber(id), row[PG_ProtectedApplicationResourceGUID], (row[PG_ABACCheck] == true or row[PG_ABACCheck] == "true")
                end
            end
            local pattern = row[PG_MatchingPattern]
            print("pattern: ", pattern)
            if type(pattern) == "string" and #pattern > 0 and ngx.re.find(path, pattern, "jJo") then
                return tonumber(id), row[PG_ProtectedApplicationResourceGUID], (row[PG_ABACCheck] == true or row[PG_ABACCheck] == "true")
            end
        end
        return false
    end
}
mt.__index = mt


local _M = {}

_M.new = function()
    local config = {}
    -- current state process function
    local handler

    local function saveRbacRights(results)
        print"saveRbacRights"
        local rights = {}
        config.rights = rights

        if results == nil or #results == 0 then
            handler = function() return config end
            return config
        end

        for i = 1, #results do
            local row = results[i]
            assert(#row == ABAC_FIELDS)
            local key = row[ABAC_PERSON_ID] .. ":" .. row[ABAC_PAGE_ID]
            --print(key)
            rights[key] = true
        end
        handler = function() return config end
        return config
    end

    local function processGetPages(results)
        if results == nil or #results == 0 then
            handler = saveRbacRights
            return config
        end

        -- process GetPages results
        for i = 1, #results do
            local row = results[i]
            assert(#row == PG_FIELDS)
            local id = row[PG_ID]
            local host = assert(getPageHost(config, row[PG_AppID]))
            config[host].pages[tostring(id)] = row
        end
        handler = saveRbacRights
        return config
    end

    local function processGetApplications(results)
        if results == nil or #results == 0 then
            handler = processGetPages
            return ""
        end
        local appIDs = {}
        for i = 1, #results do
            local row = results[i]
            assert(#row == APP_FIELDS)
            local id = row[APP_ID]
            local host = assert(getApplicationHost(config, row[APP_ServiceProviderID]))
            appIDs[#appIDs + 1] = id
            config[host].app = row
        end
        assert(config.size == #appIDs)
        handler = processGetPages
        return table.concat(appIDs, ",")
    end

    handler = function(results, guids)
        assert(#results)
        local serviceProviderIDs = {}

        for i = 1, #results do
            local row = results[i]
            assert(#row == SP_FIELDS)

            if guids[row[SP_GUID]] then
                local id = row[SP_ID]
                serviceProviderIDs[#serviceProviderIDs + 1] = id
                local host = assert(string.match(row[SP_AssertionConsumerURL], '^(https?://[^/]+)'), row[SP_AssertionConsumerURL])
                host = normalizeHost(host)
                print(host)
                assert( not config[host], "Multiple SP records for one host: ".. host)
                config[host] = {
                    host = host,
                    pages = {},
                }
                config[host].sp = row
            end
        end

        handler = processGetApplications
        config.size = #serviceProviderIDs
        return table.concat(serviceProviderIDs, ",")
    end

    return function(...)
        if select("#", ...) == 0 then
            return config
        end

        return handler(...)
    end
end

_M.checkStaticAbacRights = function(config, protectedPageId, personId)
    local key = personId .. ":" .. protectedPageId
    return config.rights[key] ~= nil
end

_M.open = function(config, scheme_host)
    scheme_host = normalizeHost(scheme_host)
    return setmetatable(config[scheme_host], mt)
end

return _M
