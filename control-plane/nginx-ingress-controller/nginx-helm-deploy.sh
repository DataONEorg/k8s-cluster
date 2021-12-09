#!/bin/bash -xf

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# For debugging
#helm template ingress-nginx ingress-nginx \
#  --dry-run --debug \
#  --version=4.0.6 \
#  --repo https://kubernetes.github.io/ingress-nginx \
#  --namespace ingress-nginx --create-namespace \
#  --set controller.admissionWebhooks.enabled=false \
#  --set controller.defaultBackend.enabled=true \
#  --set controller.ingressClassResource.default=true \
#  --set controller.ingressClassResource.name=nginx \
#  --set controller.service.externalIPs={128.111.85.192} \
#  --set controller.service.type=NodePort > nginx-debug.yaml

# Upgrade and install
helm upgrade --install ingress-nginx ingress-nginx \
  --version=4.0.6 \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.defaultBackend.enabled=true \
  --set controller.ingressClassResource.default=true \
  --set controller.ingressClassResource.name=nginx \
  --set controller.service.type=NodePort \
  --set controller.service.externalIPs={128.111.85.192}
