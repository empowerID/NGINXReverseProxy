FROM openresty/openresty:alpine
LABEL maintainer="Alexander Altshuler <altexy@gmail.com>"

COPY lib/empowerid/config.lua /usr/local/openresty/lualib/empowerid/config.lua
COPY lib/empowerid/proxy.lua /usr/local/openresty/lualib/empowerid/proxy.lua
COPY third-party/lua-resty-openidc/lib/resty/openidc.lua /usr/local/openresty/lualib/resty/openidc.lua
COPY third-party/lua-resty-http/lib/resty/http.lua /usr/local/openresty/lualib/resty/http.lua
COPY third-party/lua-resty-http/lib/resty/http_headers.lua /usr/local/openresty/lualib/resty/http_headers.lua
COPY third-party/lua-resty-session/lib/resty/session /usr/local/openresty/lualib/resty/session
COPY third-party/lua-resty-session/lib/resty/session.lua /usr/local/openresty/lualib/resty/session.lua
COPY third-party/lua-resty-jwt/lib/resty/jwt.lua /usr/local/openresty/lualib/resty/jwt.lua
COPY third-party/lua-resty-jwt/lib/resty/jwt-validators.lua /usr/local/openresty/lualib/resty/jwt-validators.lua
COPY third-party/lua-resty-jwt/lib/resty/evp.lua /usr/local/openresty/lualib/resty/evp.lua
COPY third-party/lua-resty-hmac/lib/resty/hmac.lua /usr/local/openresty/lualib/resty/hmac.lua
