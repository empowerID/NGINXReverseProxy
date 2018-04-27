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

local function docker_run_nginx(image_id, model)
    image_id = image_id or "openresty/openresty:alpine"
    return stdout("docker run -d -p 80 ",
        " -v ", host_git_root, "/t/proxy/proxy.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " -v ", host_git_root, "/t/proxy/", model, ".lua:/usr/local/openresty/lualib/empowerid/model.lua:ro ",
        " -v ", host_git_root, "/lib/empowerid/mock_endpoints.lua:/usr/local/openresty/lualib/empowerid/mock_endpoints.lua:ro",
        " -v ", host_git_root, "/lib/empowerid/config.lua:/usr/local/openresty/lualib/empowerid/config.lua:ro",
        " -v ", host_git_root, "/lib/empowerid/proxy.lua:/usr/local/openresty/lualib/empowerid/proxy.lua:ro",
        " -v ", host_git_root, "/t/proxy/mock_openidc.lua:/usr/local/openresty/lualib/resty/openidc.lua:ro",
        " -v ", host_git_root, "/third-party/lua-resty-http/lib/resty/http.lua:/usr/local/openresty/lualib/resty/http.lua:ro",
        " -v ", host_git_root, "/third-party/lua-resty-http/lib/resty/http_headers.lua:/usr/local/openresty/lualib/resty/http_headers.lua:ro",
            " ", image_id)
end

local model = dofile(git_root .. "/t/mock_endpoints/model.lua")


test("No protected page, AllowNoAuthForNonProtectedPaths - true", function()
    local nginx_id = docker_run_nginx(nil, "model1")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS --fail -m 5 -L  127.0.0.1:", nginx_port, "/")
    assert(res:find("Protected site page", 1, true))
    assert(not res:find("X-my-auth"), 1, true)

    print_logs = false
end)

test("No protected page, AllowNoAuthForNonProtectedPaths - true", function()
    local nginx_id = docker_run_nginx(nil, "model2")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS --fail -m 5 -L  127.0.0.1:", nginx_port, "/")
    assert(res:find("Protected site page", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)


test("Protected page exist, not match (by prefix), AllowNoAuthForNonProtectedPaths - true", function()
    local nginx_id = docker_run_nginx(nil, "model3")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS --fail -m 5 -L  127.0.0.1:", nginx_port, "/test")
    assert(res:find("Protected site page", 1, true))
    assert(not err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, not match (by prefix), AllowNoAuthForNonProtectedPaths - false", function()
    local nginx_id = docker_run_nginx(nil, "model4")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS --fail -m 5 -L  127.0.0.1:", nginx_port, "/test")
    assert(res:find("Protected site page", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, match (by prefix), ABACCheck = false, static right not present", function()
    local nginx_id = docker_run_nginx(nil, "model4")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/prefix")
    assert(err:find("HTTP/1.1 403", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, match (by prefix), ABACCheck = false, static right ok", function()
    local nginx_id = docker_run_nginx(nil, "model5")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/prefix")
    assert(res:find("Protected site page", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, match (by prefix), ABACCheck = true, live right check fail", function()
    local nginx_id = docker_run_nginx(nil, "model6")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/prefix")
    assert(err:find("HTTP/1.1 403", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, match (by prefix), ABACCheck = true, live right check ok", function()
    local nginx_id = docker_run_nginx(nil, "model7")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/prefix")
    assert(res:find("Protected site page", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Protected page exist, match (by regexp), ABACCheck = true, live right check ok", function()
    local nginx_id = docker_run_nginx(nil, "model7")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/folder/123/page")
    assert(res:find("Protected site page", 1, true))
    assert(err:find("X-my-auth", 1, true))

    print_logs = false
end)

test("Skip auth. by regex pattern", function()
    local nginx_id = docker_run_nginx(nil, "model7")

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", nginx_id)
        end

        sh("docker stop ", nginx_id)
    end)

    local nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ",nginx_id)

    local res, err = sh_ex("curl -v -sS -m 5 -L  127.0.0.1:", nginx_port, "/folder/123/page.jpg")
    assert(res:find("Protected site page", 1, true))
    assert(not err:find("X-my-auth", 1, true))

    print_logs = false
end)
