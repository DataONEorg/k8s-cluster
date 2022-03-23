#!/bin/bash 

# helm installation instructions at https://github.com/ceph/ceph-csi/blob/devel/charts/ceph-csi-rbd/README.md

# These only need to be invoked once
helm repo add ceph-csi https://ceph.github.io/csi-charts
kubectl create namespace "ceph-csi-rbd"

kubectl create -f secret.yaml
kubectl create -f csi-config-map.yaml
# Don't need this line if the helm '--set csiConfig' flag is working

helm install "ceph-csi-rbd" ceph-csi/ceph-csi-rbd \
  --version 3.4.0 \
  --namespace "ceph-csi-rbd" \
  --set configMapName=ceph-csi-rbd\
  --set rbac.create=true \
  --set serviceAccounts.nodeplugin.create=true \
  --set serviceAccounts.provisioner.create=true \
  --set configMapName=ceph-csi-config \
  --set externallyManagedConfigmap=true \
  --set nodeplugin.name=csi-cephrbdplugin \
  --set logLevel=5 \
  --set nodeplugin.registrar.image.tag="v2.2.0" \
  --set nodeplugin.plugin.image.tag="v3.4.0" \
  --set secret.create=false \
  --set secret.name=csi-cephrbd-secret \
  --set storageClass.create=false

helm status "ceph-csi-rbd" -n ceph-csi-rbd

# uninstall
# helm uninstall "ceph-csi-rbd" --namespace "ceph-csi-rbd"
