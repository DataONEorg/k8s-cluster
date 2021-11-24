# Storage provisioning

Up to: [DataONE Cluster Overview](../cluster-overview.md)

The DataONE Kuberrnetes network needs access to persistent storage for use by both the cluster services and by applications that we deploy on the service. 

## Persistent Disk Storage For Applications

### Persistent Volumes

A Persistent Volume (PV) is a k8s resource that allows a pod to access disk storage that is external to the containers running within a pod. A PV can be configured and created so that it persists after a pod executes and is deleted. Such PVs can be accessed again by a new execution of the pod so that use cases such as databases that are updated and reused can be supported.

PVs can be created statically or dynamically.

### Persistent Volume Claim

A Persistent Volume Claim is a k8s object that is used by a pod to request the use of a PV.

### Statically Provisioned Persistent Volumes

Static PVs are created after a system administrator has manually created an OS file system or disk partition, depending on storage type. This file system will be described in a PV manifest (.yaml file). The PV manifest is used to manually create the k8s PV object.

When the PV is created, then a PVC can be created that referenced the PV. 

Pods reference the PVC in order to use the storage that was requested with the PVC.

An example of static provisioning is described in Ceph-CSI CephFS.

### Dynamically Provisioned Persistent Volumes

PVs can be created dynamically by first creating a Storage Class (SC) that described howis a PV can be created from a storage system. The underlying storage system and k8s storage driver for this system must support the creation of dynamically created PVs.

For dynamically provisioned PVs, a PV object manifest is not required.

Once the SC has been created, a PVC can be created that references the SC. When a pod references the PVC, the storage driver will then call it's storage provisioner  that will search for a volume SC that statisfiees the PVC request, and the PV will be created for the pod.

Dynamically created PVs will persist as long as the PVC that referenced it exists. Once the PVC is deleted, the referenced PV is deleted. However, if the SC was configured such that the created volume is retained, the underlying storage is not erased and can be manually accessed.

An example of dynamic provisioning is described in Ceph-CSI RBD. 

## Ceph-based Volumes

Ceph (https://docs.ceph.com/en/pacific/rados/index.html) is an open-source software storage platform that is available for use with Kubernetes (k8s) and requires installing the open-source storeage plugin Ceph CSI (https://github.com/ceph/ceph-csi). The Ceph CSI plugin provides communication between k8s and the Ceph Cluster so that pods can access disk storage on the cluster.

Details of the DataONE k8s usage of Ceph via Ceph CSI is [here](../Ceph/Ceph-CSI.md)



