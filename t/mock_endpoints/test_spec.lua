local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex = utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex
local pl_path = require"pl.path"
local pl_stringx = require"pl.stringx"
local pl_tmpname = pl_path.tmpname
local pl_file = require"pl.file"

--local git_root = os.getenv"GIT_ROOT"
local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"

local network_name = "emposerid-mock-endpoints-test-network"

local function docker_run_nginx(image)
    image_id = image_id or "openresty/openresty:alpine"
    return stdout("docker run -d --rm -p 80 ",
        " -v ", host_git_root, "/t/mock_endpoints/proxy.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " -v ", host_git_root, "/t/mock_endpoints/model.lua:/usr/local/openresty/lualib/empowerid/model.lua:ro ",
        " -v ", host_git_root, "/lib/empowerid/mock_endpoints.lua:/usr/local/openresty/lualib/empowerid/mock_endpoints.lua:ro",
        " ", image_id)
end

local model = dofile(git_root .. "/t/mock_endpoints/model.lua")


test("test", function()
    local nginx_id = docker_run_nginx()

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local curl_command_prefix = "curl -sS --fail -m 5 -L  127.0.0.1:" .. nginx_port


    local res = stdout(curl_command_prefix, "/load_model")
    assert(res:find("Model loaded"))

    res = stdout("curl -sS --fail -m 5 -L",
        " --header \"X-EmpowerID-API-Key: ", model.X_EmpowerID_API_Key, "\"",
        " --header \"Authorization: Basic ", model.basic_auth, "\"",
        " -d \"client_id=", model.client_id, "&client_secret=", model.client_secret,"&grant_type=password", "\"",
        " -X POST 127.0.0.1:", nginx_port, "/get_token")
    assert(res:find("access_token"))
    assert(res:find(model.access_token))

    res = stdout("curl -sS --fail -m 5 -L",
        " --header \"X-EmpowerID-API-Key: ", model.X_EmpowerID_API_Key, "\"",
        " --header \"Authorization: Bearer ", model.access_token, "\"",
        " --header \"Content-Type: application/json\"",
        " -d  '{\"storedProcedure\" : \"ReverseProxy_GetServiceProviders\", \"parameters\" : \"{}\"}'",
        " -X POST 127.0.0.1:", nginx_port, "/get_results")

    res = stdout("curl -sS --fail -m 5 -L",
        " --header \"X-EmpowerID-API-Key: ", model.X_EmpowerID_API_Key, "\"",
        " --header \"Authorization: Bearer ", model.access_token, "\"",
        " --header \"Content-Type: application/json\"",
        " -d  '{\"storedProcedure\" : \"ReverseProxy_GetApplications\", \"parameters\" : \"{\\\"inputParams\\\":\\\"1089\\\"}\"}'",
        " -X POST 127.0.0.1:", nginx_port, "/get_results")
    assert(res:find("16385"))

    print_logs = false
end)