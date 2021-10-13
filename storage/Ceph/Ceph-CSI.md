
# Ceph CSI

Up to: [Storage provisioning](../storage.md)

The Ceph Container Storage Interface (CSI) driver (https://github.com/ceph/ceph-csi) for Ceph Rados Block Device (RBD) and Ceph File System (CephFS) can be used to provide Ceph storage to applications running on k8s. 

The Ceph CSI k8s driver can provision k8s persistent volumes (PVs) as RBD (RADOS Block Devices) images, but accessing Ceph storage in this way currently does not allow multiple k8s pods to access the same storage  in RWX (read write many) mode. For this reason, Ceph CSI is used to provision PVs based on CephFS. 

# CephFS plugin configuration

Ceph CSI releases are available from github, for example: https://github.com/ceph/ceph-csi/releases/tag/v3.4.0.

# Persistent Volume Provisioning

# Persistent Volume Claim

# Using The PVC

