# Control Plane Configuration

Up to: [DataONE Cluster Overview](../cluster-overview.md)

The Kubernetes control plane is a replicated set of services that controls all cluster services, and sits behind a load balancer to provide fault tolerance. It is configured as a "Stacked" typology, with each control plane node also hosting one of the replicas of the `etcd` configuration service.

### Control plane high availability

Creating a fault tolerant cluster requires that redundant control planes are available should one fail. The [recommended minimal configuration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/) is to host three control planes using a stacked `etcd` topology:

![Stacked HA cluster](https://d33wubrfki0l68.cloudfront.net/d1411cded83856552f37911eb4522d9887ca4e83/b94b2/images/kubeadm/kubeadm-ha-topology-stacked-etcd.svg)

This is the approach that we have taken for the DataONE cluster. One of the three control-plane nodes can be taken offline to be upgraded, maintained, or migrated to a new host, and the remaining two can still achieve a quorum. See [control plane configuration](control-plane/control-plane.md) for details.

## Control Plane Configuration

Describe control-plane configuration...

## Load Balancer

Decribe Load Balancer configuration...

## etcd service

Decribe etcd service configuration...
