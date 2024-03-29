# Overview of the DataONE Kubernetes Cluster

The DataONE [Kubernetes](https://kubernetes.io/) cluster provides a data processing and storage resource for use across the DataONE suite of services.

The main purpose of this cluster is to utilize many of the code [features of Kubernetes](https://kubernetes.io/#features) for our applications:

- allow us to utilize [12-factor app](https://12factor.net/) design principles
- fault tolerance and high availability even across operating system upgrades
- ability to perform rolling upgrdes with the ability to roll back
- horizontal scalability to distribute large repetitive tasks across a large cluster
- ability to use heterogeneous and older servers in the cluster
- ability to separate distributed computing processes from a robust distributed storage system

## High Availability and Fault Tolerance

The main approach to both fault tolerance and high availability is to design applications using [Kubernetes Pods](https://kubernetes.io/docs/concepts/workloads/pods/) as the basis for all application components. Pods represent an application's processes as a set of linked containers based on declaratively defined images using Docker. Each pod runs a single instance of the application, and can be scaled easily by creating additional pod instances on the cluster. Pods are designed to be relatively ephemeral, with the Kubernetes control plane able to start new pod instances on any node in the cluster and terminate existing pods with impunity. This enables fault tolerance because, when hardware or software problems arise, the problematic pod can be quickly removed and replaced with a functioning version on another node. For this to work well, pods need to be designed to be able to be started and stopped at any time without losing work, to start and stop quickly when requested, and to be able to pick up work that may have been stopped or abandoned by other pods that were terminated.

Details of the cluster are provided in the fillowing sections:

- [Cluster Overview](cluster-overview.md)
    - [Network](network/network.md)
    - [Ceph Storage](storage/storage.md)
    - [Control Plane](control-plane/control-plane.md)
    - [Authorization](authorization/authorization.md)
