local _M = {}

_M.sh = function(...)
    local command = table.concat({...})
    print(command)
    local ret = os.execute(command)
    assert(ret == 0, "sh [" .. command .. "] exit with code: " .. ret)
end

local utils = require"pl.utils"

_M.stderr = function(...)
    local command = table.concat({...})
    print(command)
    local ok, status, _, stderr = utils.executeex(command, true)
    assert(ok, "stderr [" .. command .. "] fail")
    assert(status == 0, "stderr [" .. command .. "] exit with code: " .. status)
    stderr = stderr:gsub('^%s+', '')
    stderr = stderr:gsub('%s+$', '')
    print(stderr)
    return stderr
end

_M.stdout = function(...)
    local command = table.concat({...})
    print(command)
    local ok, status, stdout, stderr = utils.executeex(command)
    if not ok then
        print(stderr)
    end
    assert(ok, "stdout [" .. command .. "] fail")
    assert(status == 0, "stdout [" .. command .. "] exit with code: " .. status)
    stdout = stdout:gsub('^%s+', '')
    stdout = stdout:gsub('%s+$', '')
    print(stdout)
    return stdout
end

_M.sh_ex = function(...)
    local command = table.concat({...})
    print(command)
    local ok, status, stdout, stderr = utils.executeex(command, true)
    print(stderr)
    assert(ok, "sh_ex [" .. command .. "] fail")
    assert(status == 0, "stdout [" .. command .. "] exit with code: " .. status)
    stdout = stdout:gsub('^%s+', '')
    stdout = stdout:gsub('%s+$', '')
    print(stdout)
    stderr = stderr:gsub('^%s+', '')
    stderr = stderr:gsub('%s+$', '')
    return stdout, stderr
end


_M.sleep = function(n, quiet)
    if not quiet then print("Waiting " .. n .. " seconds ...") end
    os.execute("sleep " .. tonumber(n))
end

return _M
