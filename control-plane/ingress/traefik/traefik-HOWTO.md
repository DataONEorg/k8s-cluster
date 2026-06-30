# Traefik HOWTO

How to configure a traefik ingress definition to do these things we already do in (deprecated) ingress-nginx:

## Contents:
* [Request Size and Duration](#request-size-and-duration)
* [Host Aliases](#host-aliases)

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

## Host Aliases

For example, to add aliases for `data.nceas.ucsb.edu` and `ecogrid.ecoinformatics.org` to `knb.ecoinformatics.org`:

```yaml
#file: noinspection YAMLUnusedAnchor
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
  name: ingress-nginx-example
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
