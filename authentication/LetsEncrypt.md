# Managing Let's Encrypt Certificates With cert-manager

A Let's Encrypt certificate is used TLS termination in the DataONE k8s cluster.

The `cert-manager` utility is used to renew the Let's Encrypt (LE) certificate. This utility is installed as a k8s service. It can be configured to watch Ingress resources that provide TLS termination, and update the LE certificate that is used by an Ingress. The LE cert is made available to an Ingress as a k8s secret that contains the certificate, which can then be made available to the Ingress Controller that is managing the ingress resources.

## Installing cert-manager

The installation of cert-manager is described at https://cert-manager.io/docs/installation. cert-manager can be installed from k8s manifest files or using Helm. For the DataONE k8s cluster, the installation command that was used is shown here:

```
helm install cert-manager \
jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--version v1.6.0 \
--set installCRDs=true
```

The `--set installCRDs=true` argument causes custom k8s resources to be installed and made available to cert-manager.

## Configuring cert-manager 

Several k8s custom resource definitions were added to k8s with the cert-manager installation. An instance of the custom resource type`ClusterIssuer` needs to be created.

The `ClusterIssuer` resource provides the information that cert-manager needs to communicate with the Let's Encrypt certificate service to request and receive new certificates. The file `production-issuer.yaml` shows an example `ClusterIssuer`:

```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: slaughter@nceas.ucsb.edu
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
         class: nginx
```

This issuer will be used by cert-manager for any Ingress resource that has been configured to be recognized by cert-manager. The next section describes how to configure the Ingress.

## Configure and Deploy Ingress resource

When a ClusterIssue has been added, cert-manager will scan all namespaces for Ingress resources that have been configured for that issuer. An annotation is added to the Ingress manifest that will signal cert-manager to obtain an LE cert for that Ingress. For example, the following Ingress `ingress-metadig.yaml`, has the 'letsencrypt-prod' annotation:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: metadig
  namespace: metadig
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-origin: '$http_origin'
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
      - api.test.dataone.org
    secretName: ingress-nginx-tls-cert
  rules:
  - host: api.test.dataone.org
    http:
      paths:
      - path: /quality
        pathType: Prefix
        backend:
          service:
            name: metadig-controller
            port:
              number: 8080
```

cert-manager will find this Ingress and create a k8s custom resource of type `Certificate,` that will be used to request a certificate from the LE service. The `tls` section of the Ingress will be inspected, and the host names found there will be added to the certificate `Subject Alternative Names` list - the list of DNS names that can be accessed with this certificate. In this case the DNS name `api.test.dataone.org` will be used.

Also note that the Ingress `ingressClassName` is set to `nginx`. The `ClusterIssuer` has been configured to use this same name in the `solvers' section with the `http01` ingress class of `nginx` on the last line of the file, so that this LE solver will be used for the LE certificate challenge for this certificate.

Add this Ingress with the command:

```
kubectl create -f ingress-metadig.yaml
```

After cert-manager requests and updates the certificate, it can be inspected with the command

```
$ kubectl describe ingress metadig -n metadig

NAME      CLASS   HOSTS                  ADDRESS          PORTS     AGE
metadig   nginx   api.test.dataone.org   128.111.85.190   80, 443   3h51m
metadig@docker-dev-ucsb-1:~/deployments/metadig-engine$ kubectl describe ingress metadig -n metadig
Name:             metadig
Namespace:        metadig
Address:          128.111.85.190
Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
TLS:
  ingress-nginx-tls-cert terminates api.test.dataone.org
Rules:
  Host                  Path  Backends
  ----                  ----  --------
  api.test.dataone.org
                        /quality   metadig-controller:8080 (192.168.50.133:8080)
Annotations:            cert-manager.io/cluster-issuer: letsencrypt-prod
                        nginx.ingress.kubernetes.io/cors-allow-credentials: true
                        nginx.ingress.kubernetes.io/cors-allow-methods: GET, POST, OPTIONS
                        nginx.ingress.kubernetes.io/cors-allow-origin: $http_origin
                        nginx.ingress.kubernetes.io/enable-cors: true
Events:                 <none>
```

Next, the certificate can be viewed:

```
$ kubectl describe secret ingress-nginx-tls-cert -n metadig
Name:         ingress-nginx-tls-cert
Namespace:    metadig
Labels:       <none>
Annotations:  cert-manager.io/alt-names: api.test.dataone.org
              cert-manager.io/certificate-name: ingress-nginx-tls-cert
              cert-manager.io/common-name: api.test.dataone.org
              cert-manager.io/ip-sans:
              cert-manager.io/issuer-group: cert-manager.io
              cert-manager.io/issuer-kind: ClusterIssuer
              cert-manager.io/issuer-name: letsencrypt-prod
              cert-manager.io/uri-sans:

Type:  kubernetes.io/tls

Data
====
tls.crt:  5607 bytes
tls.key:  1679 bytes
```
