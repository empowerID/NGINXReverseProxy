#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker stop empowerid_flow2 && docker rm stop empowerid_flow2 && true

docker run -d -p 80:80 \
    --name empowerid_flow2 \
    -e CLIENT_ID -e CLIENT_SECRET \
    -v ${DIR}/proxy.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro \
    empowerid/reverseproxy:alpine-1
