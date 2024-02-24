# K8s Backups


## Summary
We are using [Velero](https://velero.io) to backup our two K8s clusters (k8s and k8s-dev) to the Anacapa Ceph storage cluster via object storage.



## Operations

### Run a manual backup
```
velero backup create backup-full-1
```

### Check on backups
```
velero backup get
velero backup describe --details backup-full-1 
velero backup logs backup-full-1
```


## Setup
Velero is run from a location with access to both the K8s/K8s-dev admin credentials and the Anacapa Velero S3 user credentials. This can be a VM, a laptop, etc. 

### K8s-dev

Velero 1.13.0 FSB install options (current):
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket k8s-dev \
  --secret-file /Users/outin/.aws/velero \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu:9000,s3ForcePathStyle=true \
  --use-node-agent \
  --use-volume-snapshots=false \
  --uploader-type=kopia \
  --default-volumes-to-fs-backup
```

Velero 1.13.0 CSI Snapshot install options (partially works, but does not back up PVC without a storage class):
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0,velero/velero-plugin-for-csi:v0.7.0 \
  --bucket k8s-dev \
  --secret-file /Users/outin/.aws/velero \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu:9000,s3ForcePathStyle=true \
  --snapshot-location-config region=default \
  --use-node-agent \
  --use-volume-snapshots=true \
  --features=EnableCSI
```


## Changing Install Options


### Delete Velero 
Velero can be completely removed from k8s with the following commands. This may be required to change install options.

```
kubectl delete namespace/velero clusterrolebinding/velero
kubectl delete crds -l component=velero
```


### Modifying memory settings

https://velero.io/docs/main/customize-installation/#customize-resource-requests-and-limits

```console
$ kubectl edit deploy velero -n velero
deployment.apps/velero edited

$ kubectl patch deployment velero -n velero --patch '{"spec":{"template":{"spec":{"containers":[{"name": "velero", "resources": {"limits":{"cpu": "4", "memory": "4096Mi"}, "requests": {"cpu": "2", "memory": "1024Mi"}}}]}}}}'
deployment.apps/velero patched

$ kubectl patch daemonset node-agent -n velero --patch '{"spec":{"template":{"spec":{"containers":[{"name": "node-agent", "resources": {"limits":{"cpu": "4", "memory": "8192Mi"}, "requests": {"cpu": "2", "memory": "4096Mi"}}}]}}}}'
daemonset.apps/node-agent patched
```
