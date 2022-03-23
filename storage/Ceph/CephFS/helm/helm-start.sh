#!/bin/bash -x
# helm installation instructions at https://github.com/ceph/ceph-csi/blob/devel/charts/ceph-csi-cephfs/README.md

# These only need to be invoked once
helm repo add ceph-csi https://ceph.github.io/csi-charts
kubectl create namespace ceph-csi-cephfs
kubectl create -f secret.yaml
# Don't need this line if the helm '--set csiConfig' flag is working
kubectl create -f csi-config-map.yaml

# Commas have to be escaped in JSON passed to helm via the --set argument. See https://github.com/helm/helm/issues/1556, https://github.com/helm/helm/issues/5618

helm install "ceph-csi-cephfs" ceph-csi/ceph-csi-cephfs \
  --version 3.4.0 \
  --namespace "ceph-csi-cephfs" \
  --set configMapName=ceph-csi-config \
  --set rbac.create=true \
  --set serviceAccounts.nodeplugin.create=true \
  --set serviceAccounts.provisioner.create=true \
  --set configMapName=ceph-csi-config \
  --set externallyManagedConfigmap=true \
  --set nodeplugin.name=csi-cephfsplugin \
  --set logLevel=5 \
  --set nodeplugin.registrar.image.tag="v2.2.0" \
  --set nodeplugin.plugin.image.tag="v3.4.0" \
  --set secret.create=false \
  --set secret.name=csi-cephfs-secret \
  --set storageClass.create=false 


helm status "ceph-csi-cephfs" --namespace "ceph-csi-cephfs"
