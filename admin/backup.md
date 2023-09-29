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

Velero 1.12.0 install options:
```
./velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket k8s-dev \
  --secret-file /Users/outin/.aws/velero \
  --backup-location-config region=default,s3Url=https://ceph.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
  --use-volume-snapshots=false \
  --uploader-type=kopia \
  --use-node-agent \
  --default-volumes-to-fs-backup
```


## Changing Install Options

Velero can be completely removed from k8s with the following commands. This may be required to change install options.

```
kubectl delete namespace/velero clusterrolebinding/velero
kubectl delete crds -l component=velero
```
