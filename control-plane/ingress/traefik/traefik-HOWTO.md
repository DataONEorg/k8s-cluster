# Traefik HOWTO

How to configure a traefik ingress definition to do these things we already do in (deprecated) ingress-nginx:

## Contents:
* [Redirects (Rewrite Rules)](#redirects-rewrite-rules)
* [Enable CORS](#enable-cors)
* [Adding Headers](#adding-headers)
* [Request Size and Duration](#request-size-and-duration)
* [Host Aliases](#host-aliases)
* [Mutual TLS](#mutual-tls)
* [Middleware Chain](#middleware-chain)

## Request Size and Duration

Metacat requires long upload times and large payloads, which necessitated the customization of several nginx annotations. Here are the traefik equivalents for each one. Note that we can simply use the traefik defaults for all except one (nginx `proxy-send-timeout` replaced by traefik `readTimeout`):

| Nginx Annotation        | Override | Summary                                     | Traefik Equivalent & default value                                  | Action   |
|-------------------------|----------|---------------------------------------------|---------------------------------------------------------------------|----------|
| client-body-buffer-size | 1m       | Sets memory buffer for request body         | N/A (Streaming is default)                                          | ✅        |
| client_max_body_size    | 0        | Max allowed size of request body            | Unlimited (Streaming is default)                                    | ✅        |
| proxy-body-size         | 0        | Proxy-level max request body size           | Unlimited (Streaming is default)                                    | ✅        |
| proxy-buffering         | off      | Disables buffering of the response body     | Default Behavior Streaming                                          | ✅        |
| proxy-read-timeout      | 3600     | Timeout for reading response from backend   | `respondingTimeouts.responseHeaderTimeout` 0s (Unlimited)           | ✅        |
| proxy-request-buffering | off      | Disables buffering of the request body      | Default Behavior Streaming                                          | ✅        |
| proxy-send-timeout      | 3600     | Timeout for streaming request to backend    | `transport.respondingTimeouts.readTimeout`: default 60s             | ⚠️ 3600s |
| send-timeout            | 3600     | Timeout for transmitting response to client | `transport.respondingTimeouts.writeTimeout`: default 0s (Unlimited) | ✅        |

> [!NOTE]
> `ingress-nginx` allowed setting `proxy-send-timeout` individually in each app's ingress config. However, traefik's `transport.respondingTimeouts.readTimeout` can only be set globally in the traefik config itself ([see values overrides](./values-overrides-traefik.yaml)). It cannot be customized for individual apps.

## Redirects (Rewrite Rules)

Redirects are defined in Middleware objects:

```yaml
## OLD APPROACH - ingress-nginx uses:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-example
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      rewrite ^/(sitemap.+) /goa/sitemaps/$1 redirect;
      rewrite ^/robots.txt /goa/robots.txt redirect;
      if ($host = "evos.nceas.ucsb.edu") {
        return 301 https://goa.nceas.ucsb.edu$request_uri;
      }
#...etc
---
## NEW APPROACH - define and reference a Middleware object for each of the redirects:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-example
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<release>-middleware-chain@kubernetescrd
```

Because only one middleware can be added to the ingress annotations, a middleware chain definition is used - [see the Middleware Chain section](#middleware-chain). In addition to the chain, you must also deploy the Middleware definitions for the 3 redirects, as shown in the [redirect-middlewares.yaml example](./howto-examples/redirect-middlewares.yaml).

Note that Traefik does not provide server variables (like nginx's `$request_uri}`, `${host}` etc). However, multiple capturing groups can be created with the syntax `()`, and then these can be back-referenced with the syntax `${1}`, `${2}` etc. Here's an example to remove the `/remove-me` path element

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: release-name-test-redirect
spec:
  redirectRegex:
    regex: "^https://([^/]+)/remove-me/(.*)"
    replacement: "https://${1}/${2}"
    permanent: true
```

## Enable CORS

```yaml
## OLD APPROACH - ingress-nginx uses:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-example
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      # Metacat Cors Setup

      set $cors 'true';

      if ($request_method = 'OPTIONS') {
        set $cors ${cors}options;
      }

      if ($cors = "true") {
        more_set_headers 'Access-Control-Allow-Origin: $http_origin';
        more_set_headers 'Access-Control-Allow-Credentials: true';
        more_set_headers 'Access-Control-Allow-Methods: POST, PUT, GET, OPTIONS';
        more_set_headers 'Access-Control-Allow-Headers: DNT,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';

        more_set_headers 'Access-Control-Max-Age: 1728000';
      }

      if ($cors = "trueoptions") {
        more_set_headers 'Access-Control-Allow-Origin: $http_origin';
        more_set_headers 'Access-Control-Allow-Credentials: true';
        more_set_headers 'Access-Control-Allow-Methods: POST, PUT, GET, OPTIONS';
        more_set_headers 'Access-Control-Allow-Headers: DNT,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';

        more_set_headers 'Access-Control-Max-Age: 1728000';
        more_set_headers 'Content-Type: text/plain charset=UTF-8';
        more_set_headers 'Content-Length: 0';
        return 204;
      }
#...etc
---
## NEW APPROACH - define and reference a Middleware object:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-example
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<release>-cors-headers@kubernetescrd
#...etc
```
The necessary Middleware definition for CORS headers can be seen in the file [headers-middelware.yaml](./howto-examples/headers-middleware.yaml). 

NOTE: Only one middleware can be added to the ingress annotations. If your setup requires more than one, use a middleware chain definition - [see the Middleware Chain section](#middleware-chain).

## Adding Headers

If you need additional custom headers, follow the example in the [Enable CORS section](#enable-cors)

## Host Aliases

For example, to add aliases for `data.nceas.ucsb.edu` and `ecogrid.ecoinformatics.org` to `knb.ecoinformatics.org`:

```yaml
## OLD APPROACH - ingress-nginx uses:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-example
  annotations:
    nginx.ingress.kubernetes.io/server-alias: data.nceas.ucsb.edu, ecogrid.ecoinformatics.org
spec:
  rules:
    - host: knb.ecoinformatics.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: metacatknb-hl
                port:
                  number: 8080
---
## NEW APPROACH - traefik has no direct equivalent. Instead, configure
## multiple host entries like this:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-example
  annotations:
    nginx.ingress.kubernetes.io/server-alias: data.nceas.ucsb.edu, ecogrid.ecoinformatics.org
spec:
  rules:
    - host: knb.ecoinformatics.org
      http: &aliasedRules     # Use a YAML anchor to reduce repetition
        paths:
          - path: /metacat
            pathType: Prefix
            backend:
              service:
                name: metacatknb-hl
                port:
                  number: 8080
    - host: ecogrid.ecoinformatics.org
      http: *aliasedRules     # Use a YAML anchor to reduce repetition
    - host: data.nceas.ucsb.edu
      http: *aliasedRules     # Use a YAML anchor to reduce repetition
```

## Mutual TLS

Also known as "mTLS" or "Mutual Authentication with a Client-Certificate".

```yaml
## OLD APPROACH - ingress-nginx uses:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-example
  annotations:
    nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
    nginx.ingress.kubernetes.io/auth-tls-secret: knb/d1-ca-chain
    nginx.ingress.kubernetes.io/auth-tls-verify-client: optional_no_ca
    nginx.ingress.kubernetes.io/auth-tls-verify-depth: "10"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_input_headers "X-Proxy-Key: your-secret-key-here";
#...etc
---
## NEW APPROACH - define and reference Middleware and TLSOption objects:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-example
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<release>-middleware-chain@kubernetescrd
    traefik.ingress.kubernetes.io/router.tls.options: <namespace>-<release>-mtls-policy@kubernetescrd
```

You must also deploy the Middleware and TLSOption definitions as shown in the [mtls-setup.yaml example](./howto-examples/mtls-setup.yaml).

Only one middleware can be added to the ingress annotations. Because mTLS setup requires more than one, a middleware chain definition is used - [see the Middleware Chain section](#middleware-chain).


## Middleware Chain

Only one `traefik.ingress.kubernetes.io/router.middlewares` middleware annotation can be added to the ingress definition. If more than one is required, use a middleware chain definition, which chains together all the other Traefik Middlewares; see the example in [middleware-chain.yaml](./howto-examples/middleware-chain.yaml). Then, only this single definition needs to be referenced in the ingress annotations, like so:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-example
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<release>-middleware-chain@kubernetescrd
#...etc
```
