NGINXReverseProxy
=================

This is the private repository, developed by Alexander Altshuler (altexy@gmail.com) for Patrick Parker

This git repository has some submodules, use command below to clone:

```
git clone --recursive git@github.com:patrickparker/NGINXReverseProxy.git
```

### Synopsys

Below is minimal required nginx configuration file with custom error pages example:


```
worker_processes auto;

events {
    #production server may have the number below much bigger
    worker_connections 1024;
}

# it is bad idea to place such security credentials into git repository
# the best practise is to pass it to nginx configuration from OS environment
env CLIENT_ID;
env CLIENT_SECRET;
# possibly empowerid_api_key and token_endpoint_basic_auth also
# should be passed this way

http {
    resolver 8.8.8.8 ipv6=off;

    # cache for discovery metadata documents
    lua_shared_dict discovery 1m;
    
    # cache for JWKs
    lua_shared_dict jwks 1m;

    # session storage
    lua_shared_dict sessions 10m;

    # our module shared storage
    lua_shared_dict empowerid_proxy_config 10m;

    # block below is optional, but may inproove performance (TODO - should be tested)    
    init_by_lua_block {
        require "resty.core"
        collectgarbage("collect")  -- just to collect any garbage
    }

    # here we configure our module
    # most configuration parameters are self described
    init_worker_by_lua_block {
        local opts = {
            redirect_uri_path = "/oauth2callback",
            discovery = "https://sso.empoweriam.com/oauth/.well-known/openid-configuration",
            client_id = os.getenv("CLIENT_ID"),
            client_secret = os.getenv("CLIENT_SECRET"),
            ssl_verify = "no",
            logout_path = "/logout",
            service_providers_guids = {
                "927BF3D4-1CCA-47D3-8EDE-47994CD78B62",
                "30ECA9FA-2F0B-4D55-9207-320500030E03",
              },
            hasaccesstopage_endpoint = "https://sso.empoweriam.com/api/services/v1/hasaccess/hasaccesstopage",
            empowerid_api_key = "",
            get_results_endpoint = "https://sso.empoweriam.com/api/services/v1/ReverseProxy/GetResults",
            token_endpoint = "https://sso.empoweriam.com/oauth/v2/token",
            token_endpoint_basic_auth = "",
        }
        require"empowerid.proxy"(opts)
    }

    # here may be multiple server blocks assuming that appropriate service_providers_guids
    # were configured

    server {
        listen 80;

        location / {
            # for single box proxy installation the recommended session storage is shared memory
            set $session_storage shm;
            # for multiple proxies serving the same domain we will need memcached or redis storage (TODO)
            
            # how to configure custom error pages
            # upon error below it would results with internal redirect
            # to error location (see after current location)
            error_page 403 /errors/403.html;
            error_page 500 /errors/500.html;

            # here is almost all work would be done
            access_by_lua_block {
                require"empowerid.proxy"()
            }
            
            # below is minimal required proxy directives
            proxy_http_version 1.1;
            proxy_redirect off;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Connection "";

            # it is possible to specify an IP, FQDN, optional port
            # also it is possible to specify nginx upstream name
            proxy_pass http://127.0.0.1:8080;
        }
        
        location ^~ /errors/ {
            # this location is only for internal redirect, not public access
            internal;
            
            # specify where is error pages are located
            root /usr/local/openresty/nginx/html;
        }
        
    }
}
```


### How to run

Assuming that current directory contains a file proxy.nginx config file like above 

```
docker run -d -p 80:80 --restart unless-stopped \
    --name empowerid_proxy \
    -e CLIENT_ID -e CLIENT_SECRET \
    -v ./proxy.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro \
    empowerid/reverseproxy:alpine-1
```

