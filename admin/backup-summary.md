# K8s Backups Quick Reference

See [backup.md](backup.md) for details of how backup software is installed & configured

| Creation Method | K8s Resource Type       | What's Backed Up?           | Backup Method              | Backup Location                             | Recovery                                                                                          |
|-----------------|-------------------------|-----------------------------|----------------------------|---------------------------------------------|---------------------------------------------------------------------------------------------------|
| **Manual**      | CephFS Volumes          | Files on disk ONLY          | scheduled CephFS snapshots | `datateam:/mnt/ceph/.snap/`                 | Anyone with `datateam` access: manual copy from snapshots                                         |
|                 |                         | `datateam:/mnt/ceph/.snap/` | Restic                     | Onsite servers @ NCEAS office               | Nick: Restic restore                                                                              |
| **Dynamic**     | CephFS & RBD Volumes    | PVCs, PVs, & Files on disk  | Velero (CSI snapshots)     | Object Storage: `s3.anacapa.nceas.ucsb.edu` | K8s admins: `velero restore` ([full or partial](https://velero.io/docs/main/resource-filtering/)) |
| **Any**         | All other K8s Resources | Everything Else             | Velero                     | Object Storage: `s3.anacapa.nceas.ucsb.edu` | K8s admins: `velero restore` ([full or partial](https://velero.io/docs/main/resource-filtering/)) |
