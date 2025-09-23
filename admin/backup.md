# K8s Backups

## Summary

See [backup-summary.md](backup-summary.md) for a quick reference of what is backed up where, and how to restore.

[Velero](https://velero.io) is used to backup our two K8s clusters (k8s and k8s-dev) to the Anacapa Ceph storage cluster via object storage to a MinIO server.

We are using CSI volume snapshots and the Opt-out approach for backing up K8s resources and dynamically created Ceph RBD and FS volumes. 

Manually created CephFS volumes are not included in Velero backups and are backed up via [Restic](https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/server_backup_restic.md)


## Operations
### Run a full backup
```
velero backup create backup-full-1 --snapshot-move-data
```

### Run a backup of a namespace
```
velero backup create hwitw-backup-1 --snapshot-move-data --include-namespaces hwitw
```

### Check on backups
```
velero backup get
velero backup describe --details backup-full-1 
velero backup logs backup-full-1
kubectl -n velero get datauploads -l velero.io/backup-name=full-test-1 -o yaml
kubectl -n velero logs deploy/velero
```

### Create automatic backup schedules
```
velero schedule create full-backup --schedule="0 3 * * *" --ttl 2160h0m0s --snapshot-move-data
velero schedule create full-backup-monthly --schedule="0 15 1 * *" --ttl 26280h0m0s --snapshot-move-data
```


## Setup
Velero is run from a location with access to both the K8s/K8s-dev admin credentials and the Anacapa Velero S3 user credentials. This can be a VM, a laptop, etc. 

### Overview
- Install the velero binary from homebrew, GitHub, etc
- Setup kubectl so that it can connect to the K8s clusters as admin
- Run the `velero install` command
- Increase the memory limits and backup timeout
- Create a schedule


### K8s-prod
Velero 1.16.0 FSB install options:
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.12.0 \
  --bucket k8s-prod \
  --secret-file /Users/outin/.aws/minio-k8s-prod \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
  --snapshot-location-config region=default \
  --use-node-agent \
  --use-volume-snapshots=true \
  --features=EnableCSI
```

### K8s-dev
Velero 1.16.0 CSI Snapshot install options:
```
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.12.0 \
  --bucket k8s-dev \
  --secret-file /Users/outin/.aws/velero \
  --backup-location-config region=default,s3Url=https://s3.anacapa.nceas.ucsb.edu,s3ForcePathStyle=true \
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
After reinstalling schedules and memory settings will need to be reconfigured.


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


## Finding volumes to exclude

https://velero.io/docs/main/file-system-backup/#using-the-opt-out-approach

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

# Exclude PVC
$ kubectl label -n arctic pvc/metacatarctic-metacat-metacatarctic-0 velero.io/exclude-from-backup=true
$ kubectl get -n arctic pvc/metacatarctic-metacat-metacatarctic-0 -o jsonpath='{.metadata.labels}'

# Exclude PV
$ kubectl label pv cephfs-repos-rom velero.io/exclude-from-backup=true
persistentvolume/cephfs-repos-rom labeled
$ kubectl describe pv cephfs-repos-rom | grep Labels:
Labels:          velero.io/exclude-from-backup=true
```

## Monitoring
Check_MK is monitoring the backup status and will send alerts if backups are not completed successfully.
