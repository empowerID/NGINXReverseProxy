local _M = {}

_M.authenticate = function()
    ngx.header["X-my-auth"] = "alexander"
    return { id_token = { attrib = {  username = "alexander", ReverseProxyPersonID = 20}}}
end

return _M
