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

After the PV is created, then a PVC can be created that referenced the PV. 

Pods reference the PVC in order to use the storage that was requested with the PVC.

An example of static provisioning is described in [Ceph-CSI CephFS](./Ceph/Ceph-CSI-CephFS.md).

### Dynamically Provisioned Persistent Volumes

PVs can be created dynamically by first creating a k8s Storage Class (SC) that described how a PV should be created from a storage system. The underlying storage system and k8s storage driver for this system must support the creation of dynamically created PVs.

For dynamically provisioned PVs, a PV object manifest is not required.

Once the SC has been created, a PVC can be created that references the SC. When a pod references the PVC, the storage driver will then call it's storage provisioner that will search for a volume SC that satisfies the PVC request, and then the PV will be created for the pod.

Dynamically created PVs will persist as long as the PVC that referenced it exists. Once the PVC is deleted, the referenced PV is deleted. However, if the SC was configured such that the created volume is retained, the underlying storage is not erased and can be manually accessed.

An example of dynamic provisioning is described in [Ceph-CSI RBD](./Ceph/Ceph-CSI-RBD.md). 

## Ceph-based Volumes

[Ceph](https://docs.ceph.com/en/pacific/rados/index.html) is an open-source software storage platform that can be configured for use with Kubernetes (k8s).

k8s can access a storage systems if a storage driver is available for the storage system. Storage drivers used by k8s must adhere to the [Container Storage Interface](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/) specification. These plugins can either be included with the k8s release, or provided as separate software.

The CSI storage driver for Ceph is available from the [Ceph CSI](https://github.com/ceph/ceph-csi) github repo. This driver must be installed and running on k8s before Ceph volumes can be accessed by k8s pods.

Details of the DataONE k8s usage of Ceph via Ceph CSI is [here](./Ceph/Ceph-CSI.md)

## Data Recovery

For information regarding recovering data from Ceph based persistent volumes in the event of PV deletion or other problem, see [Data Recovery](./data-recovery.md)



