This example contains example nginx configuration to authenticate users
using Google OAuth 2.0 API.

Dependencies
============

The only deps is docker-ce.

All instructions below assume Ubuntu 16

Older versions of Docker were called docker or docker-engine. If these are installed, uninstall them:

```
$ sudo apt-get remove docker docker-engine docker.io
```

Install fresh docker-ce

```
$ curl https://get.docker.com/ | sudo sh
$ sudo usermod -aG docker $USER
```

OAuth 2.0 API Configuration
===========================

This test must run on publicly accessible IPv4 box with any domain pointed to this address.
I use http transport for simplicity.

You must configure your project and credentials as specified at this page https://developers.google.com/identity/protocols/OpenIDConnect

Save somewhere your client id and client secret.

Authorized redirect URIs of your user credentials must be configured as below (replace with your domain):

```
http://example.com/oauth2callback
```

Scenario
========

I run nginx (OpenResty bundle with some additional modules) which serves two virtual hosts - proxy and protected site.

Proxy is configured as below:

- it pass request to the site root without authentication
- /logout url is used to logout current user
- all others pages require authentication

When user is successfully authenticated using Google OAuth 2.0 API proxy add user's email into the X-Empowerid-Username header and pass it to protetected site.
You may see the value of this header within response body.

How to run
==========

First you need to define two shell variables (replace <sometext> with saved values):
```
export CLIENT_ID=<sometext>
export CLIENT_SECRET=<sometext>
```

Run nginx:

```
$ cd test_flows/flow1
$ ./run.sh 
```

Command above will run in background `empowerid_flow1` docker container with full configured nginx, first time it may take some time to download an image.

Port 80 on local box must be free.

How to test
===========

I edit `/etc/hosts` file and add line below (replace with your domain):
```
127.0.0.1	example.com
```

Open example.com (replace with your domain) page in web browser.
Root page should be opened without authentication.

Open any other page - you should be redirected to Google page for authentication.
After successful authentication you will see protected page and the value of X-Empowerid-Username header (added by proxy).

In case of any error use command below and send me the whole logs:
```
docker logs empowerid_flow1
```

How to stop nginx

```
docker stop empowerid_flow1
```


