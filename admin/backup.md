# K8s Backups


## Summary
We are using [Velero](https://velero.io) to backup our two K8s clusters (k8s and k8s-dev) to the Anacapa Ceph storage cluster via object storage.



## Operations

### Run a full backup
```
velero backup create backup-full-1
```

### Run a backup of a namespace
```
velero backup create hwitw-backup-1 --include-namespaces hwitw
```

### Check on backups
```
velero backup get
velero backup describe --details backup-full-1 
velero backup logs backup-full-1
```

### Set an automatic backup schedule
```
velero schedule create full-backup --schedule="0 3 * * *" --ttl 2160h0m0s
```


## Setup
Velero is run from a location with access to both the K8s/K8s-dev admin credentials and the Anacapa Velero S3 user credentials. This can be a VM, a laptop, etc. 

### Overall steps
- Install the velero binary from homebrew, GitHub, etc
- Setup kubectl so that it can connect to the K8s clusters as admin
- Run the `velero install` command
- Increase the memory limits and backup timeout


### K8s-prod
Velero 1.13.0 FSB install options (current):
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket k8s-prod \
  --secret-file /Users/outin/.aws/minio-k8s-prod \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
  --use-node-agent \
  --use-volume-snapshots=false \
  --uploader-type=kopia \
  --default-volumes-to-fs-backup
```


### K8s-dev

Velero 1.13.0 FSB install options (current):
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket k8s-dev \
  --secret-file /Users/outin/.aws/velero \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
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
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
  --snapshot-location-config region=default \
  --use-node-agent \
  --use-volume-snapshots=true \
  --features=EnableCSI
```


## Excluding volumes
We are using the `opt-out` approach to Velero FSB backups. Everything is backed up, unless excluded. Here is how to exclude volumes:

Find the failed backup volume:
```
$ velero backup describe full-backup-20240903010056 --details

  Pod Volume Backups - kopia:
    Completed:
      ...
    Failed:
      polder/prod-gleaner-76df9dfc54-kkcgt: s3system-volume

```

Add an annotation to exclude it from backups:
```
kubectl -n YOUR_POD_NAMESPACE annotate pod/YOUR_POD_NAME backup.velero.io/backup-volumes-excludes=YOUR_VOLUME_NAME_1,YOUR_VOLUME_NAME_2,...
```

```
kubectl -n polder annotate pod/prod-gleaner-76df9dfc54-kkcgt backup.velero.io/backup-volumes-excludes=s3system-volume
kubectl -n polder get pod/prod-gleaner-76df9dfc54-kkcgt -o jsonpath='{.metadata.annotations}'
```

https://velero.io/docs/v1.13/file-system-backup/#using-the-opt-out-approach

## Finding volumes to exclude
```
kubectl get pv
kubectl describe pv cephfs-arctic-pv
kubectl describe -n jones pvc cephfs-arctic-pvc
# look for the pod names in "Used By:"
```

```
$ velero backup describe full-backup-20250206010007 --details
...
  Pod Volume Backups - kopia:
    In Progress:
      arctic/metacatarctic-d1index-77945db995-g8qw9: indexer-metacat-pv (3.41%)
...

$ kubectl describe pod -n arctic metacatarctic-d1index-77945db995-g8qw9 | grep indexer-metacat-pv -A 2 | grep ClaimName
    ClaimName:  metacatarctic-metacat-metacatarctic-0

$ kubectl describe pvc metacatarctic-metacat-metacatarctic-0 -n arctic

$ kubectl label -n arctic pvc/metacatarctic-metacat-metacatarctic-0 velero.io/exclude-from-backup=true

$ kubectl get -n arctic pvc/metacatarctic-metacat-metacatarctic-0 -o jsonpath='{.metadata.labels}'
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
- Add `- --fs-backup-timeout` to spec.template.spec.containers
- Increase memory for Velero pod
- Increase memory for node-agent pods

```console
$ kubectl edit deploy velero -n velero
deployment.apps/velero edited

$ kubectl patch deployment velero -n velero --patch '{"spec":{"template":{"spec":{"containers":[{"name": "velero", "resources": {"limits":{"cpu": "4", "memory": "16384Mi"}, "requests": {"cpu": "2", "memory": "4096Mi"}}}]}}}}'
deployment.apps/velero patched

$ kubectl patch daemonset node-agent -n velero --patch '{"spec":{"template":{"spec":{"containers":[{"name": "node-agent", "resources": {"limits":{"cpu": "4", "memory": "8192Mi"}, "requests": {"cpu": "2", "memory": "4096Mi"}}}]}}}}'
daemonset.apps/node-agent patched
```

### Change Target URL

```
velero backup-location get default -o yaml
kubectl edit -n velero BackupStorageLocation
```

