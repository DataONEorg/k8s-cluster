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

## DataONE Volume Naming Conventions

PVCs represent the persistent storage for apps, and PVs represent the backing storage location. A standard naming convention helps us to understand which PVCs are used by which applications, allows for repeated deployment of the same application, and makes it clear how volumes map to the underlying storage systems (e.g., Ceph RDB or CephFS, using static or dynamic provisioning). Our convention is to use the following naming structure:

**Naming PVCs.** For the case of PVCs, the objective is to allow us to deploy, for example, the same application through multiple helm releases while having predicatable, informative, uniquely named PVCs and no naming conflicts. In the name template below, the {release} shoud be the name of the deployed helm release, which generally should match the namespace for that deployment. In the case of a non-helm app deployment, this first component will likely be the namespace of the deployment assuming each namespace only has one app deployed in it. The second component {function} of the name is the main function within that deployment that will make use of the PVC, such as solr, metacat, or postgres. This will also often be the name of a container in the deployment, but sometimes a container will need multiple PVCs for different functions, so a short name should be chose to differentiate the purposes. The final component is a number to match the PVC to a particular instance of a StatefulSet (e.g., for the solr-0, solr-1, and solr-2 pods in a solr cluster). This last {instance} part of the name is optional if it is not needed, or can be set to `-0` as a default case. For applications that will only be deployed once and for which the main application container has the same name and only needs a single PVC, all of this will boil down to a simple name like `gnis-gnis` or `slinky-slinky`. More complex deployments will use the full 3 part naming convention.

    - Template: {release}-{function}-{instance} where the {instance} is optional
    - Examples:
        - metadig-rabbitmq-0
        - metadig-rabbitmq-1
        - metadig-solr-0
        - metadig-solr-1
        - metacatknb-solr-0
        - metacatknb-pgsql-0
        - metacatknb-metacat
        - metacatadc-solr-0
        - metacatadc-pgsql-0
        - metacatadc-metacat
        - slinky-slinky

This should enable all PVCs associated with an application to nicely sort together, and give a functional indication of the use of each PVC.

N.B.: Bitnami helm charts use a `data-` prefix but otherwise follow a similar pattern to above. For example, they might use `data-d1index-zookeeper-0` for a d1index release, but the same name would be used in different namespaces if the same release name is used. I am proposing that the `data-` part is not needed and would just make the name longer. To override the Bitnami default behavior, set the `volumeClaimTemplate` to a pattern we want to use, or otherwise just point it at a specific PVC with `persistence.existingClaimName`. 

**Naming PVs.** For PVs, naming is simpler, and is mainly used to see at a glance whether a PV was created statically or dynamically, and what type of storage resource is represented. In the case of statically named PVs, the name reflects the type of volume and then the name of the PVC that it is intended to serve. For dynamic PVs, the name represents the type of volume, and then the unique local identifier assigned by the storage class. At this point, our two main voume types are `cephfs` and `cephrbd`.

    - Template: {fstype}-{pvcname} for static PVs OR {fstype}-{localid} for dynamic PVs
    - Examples:
        - cephfs-metacatknb-solr-0
        - cephfs-metacatknb-solr-1
        - cephrbd-metacatknb-solr-0
        - cephrbd-c83f684f-ad03-4be6-b5f6-945e4639135f (a dynamic volume)
        - cephrdb-1d67d889-8636-4285-9f33-12132ef64e07 (a dynamic volume)

N.B.2: For dynamic provisioning, volume names are determined by the storage class, and particular, prefixed using the value in the storage class `volumePrefix`. For some reason, this is set to the default `pvc-` prefix for `csi-rbd-sc` for our cluster, which should be changed to a more appropriate prefix such as `cephrbd`. This can be set in the StorageClass definition by setting the parameter `volumePrefix: "cephrbd"` or something similar. If this is not possible, then its probably fine (but confusing) to leave the prefix at the default `pvc-`. To be discussed.

## Ceph-based Volumes

[Ceph](https://docs.ceph.com/en/pacific/rados/index.html) is an open-source software storage platform that can be configured for use with Kubernetes (k8s).

k8s can access a storage systems if a storage driver is available for the storage system. Storage drivers used by k8s must adhere to the [Container Storage Interface](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/) specification. These plugins can either be included with the k8s release, or provided as separate software.

The CSI storage driver for Ceph is available from the [Ceph CSI](https://github.com/ceph/ceph-csi) github repo. This driver must be installed and running on k8s before Ceph volumes can be accessed by k8s pods.

Details of the DataONE k8s usage of Ceph via Ceph CSI is [here](./Ceph/Ceph-CSI.md)

## Data Recovery

For information regarding recovering data from Ceph based persistent volumes in the event of PV deletion or other problem, see [Data Recovery](./data-recovery.md)



