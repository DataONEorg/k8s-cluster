# K8s Backups Quick Reference

See [backup.md](backup.md) for details of how backup software is installed & configured

* By default, all virtual servers, physical servers, and K8s are backed up to disk servers at NCEAS (Anacapa) nightly (unless the previous night's backup is still running).

* Disk backups are retained for 3 years (36 monthly, 90 nightly).

* CephFS Snapshots on the `pdg` subvolume (`datateam:/mnt/ceph/.snap/`) are retained for only 30 days. However, Restic backs these up at the same (36 monthly, 90 nightly) frequency.


> [!WARNING]
>
> Velero can not back up static PVs or PVCs, since it depends upon CSI snapshots, and Ceph-csi doesn't currently support snapshots for static volumes


|                                  | Cluster    | What's Backed Up?                                      | Backup Method                 | Backup Location             | Recovery                     |
|----------------------------------|------------|--------------------------------------------------------|-------------------------------|-----------------------------|------------------------------|
| **Static CephFS Volumes**        | Prod       | ⚠️ All files on `pdg` subvol (NO PVs/PVCs)             | CephFS snapshots & Restic[^1] | `datateam:/mnt/ceph/.snap/` | Manual copy from `.snap` dir |
| **Static CephFS Volumes**        | Dev        | ⚠️ _Some_ Files on `tdg` & other subvols (No PVs/PVCs) | see below[^2]                 | see below[^2]               | see below[^2]                |
| **Dynamic CephFS & RBD Volumes** | Prod & Dev | ✅ PVCs, PVs, and all files on disk                    | Velero (CSI snapshots)        | Object Storage[^3]          | K8s admins can restore[^4]   |
| **All other K8s Resources**      | Prod & Dev | ✅ Everything Else                                     | Velero                        | Object Storage[^3]          | K8s admins: can restore[^4]  |


[^1]: Anyone on `datateam` can access the last 30 days of CephFS snapshots at `datateam:/mnt/ceph/.snap/`. Files that were accidentally deleted within the past month can therefore easily be recovered by making copies from there. [Restic](https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/server_backup_restic.md), in turn, backs up `datateam:/mnt/ceph/.snap/` to servers at the NCEAS office.

[^2]: In the dev cluster, some ceph subvolumes are backed up via rsync. Some ae not backed up at all. See the [Server Backup List](https://docs.google.com/spreadsheets/d/1xFOFQ1lF90BoFLYRkpBRSNj5QqVyfG2DLnwc1znaNI4/edit?usp=sharing) for details.

[^3]: We’re using the S3 API with our own Object Storage server `s3.anacapa.nceas.ucsb.edu` for backups (currently MinIO on top of ZFS, probably changing soon).

[^4]: K8s admins can do a full or partial `velero restore` ([by using filtering options](https://velero.io/docs/main/resource-filtering/)).
