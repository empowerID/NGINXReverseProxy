#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GIT_ROOT="$DIR/../.."

docker stop empowerid_flow1 && true

docker run -d --rm -p 80:80 \
    --name empowerid_flow1 \
    -e CLIENT_ID -e CLIENT_SECRET \
    -v ${DIR}/proxy.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-openidc/lib/resty/openidc.lua:/usr/local/openresty/lualib/resty/openidc.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-http/lib/resty/http.lua:/usr/local/openresty/lualib/resty/http.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-http/lib/resty/http_headers.lua:/usr/local/openresty/lualib/resty/http_headers.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-session/lib/resty/session:/usr/local/openresty/lualib/resty/session:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-session/lib/resty/session.lua:/usr/local/openresty/lualib/resty/session.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-jwt/lib/resty/jwt.lua:/usr/local/openresty/lualib/resty/jwt.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-jwt/lib/resty/jwt-validators.lua:/usr/local/openresty/lualib/resty/jwt-validators.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-jwt/lib/resty/evp.lua:/usr/local/openresty/lualib/resty/evp.lua:ro \
    -v ${GIT_ROOT}/third-party/lua-resty-hmac/lib/resty/hmac.lua:/usr/local/openresty/lualib/resty/hmac.lua:ro \
    openresty/openresty:alpine
