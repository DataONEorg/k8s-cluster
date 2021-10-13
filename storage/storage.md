# Storage provisioning

Up to: [DataONE Cluster Overview](../cluster-overview.md)

The DataONE Kuberrnetes netwrok needs access to both local and persistent storage for use by both the cluster services and by applications that we deploy on the service. 

## Host-based local storage

Describe what host-based storage is in use, and how we plan to transition off of that to Ceph...

## Ceph-based storage cluster

Ceph (https://docs.ceph.com/en/pacific/rados/index.html) is an open-source software storage platform that is available for use with Kubernetes (k8s) and requires installing the open-source storeage plugin Ceph CSI (https://github.com/ceph/ceph-csi)

Details of the DataONE k8s usage of Ceph via Ceph CSI is [here](../Ceph/Ceph-CSI.md)

## Persistent Volumes for applications

Describe our strategy for creating `Persistent Volume` resources for applications to use when they try to create a `Persistent Volume Claim`...


