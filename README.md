# Nginx Proxy Docker Image

Nginx proxy docker image which extends jwilder/nginx-proxy

## Proxy Caching

### Enabling 

To enable proxy caching for a specific container add `PROXY_CACHE` environment variable to `true` it.

### Configuration

Proxy caching excludes the following:

 - Requests with no cache cookie set
 - Requests with HTTP Authorisation header
 - Requests with SetCookie header
 - Requests other than GET or HEAD requests
 - Requests with GitLab session coookie, Java Session Cookie (JSESSIONID), Nexus Session Cookie (NXSESSIONID)
 - Requests with Pragma or "CacheControl: no-cache" headers set



## Maintainer

This repository is maintained by [Black Pear Digital](https://www.blackpeardigital.co.uk).
