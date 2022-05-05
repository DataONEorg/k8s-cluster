# Networking Configuration

Up to: [DataONE Cluster Overview](../cluster-overview.md)

Networking for the Kubernetes cluster is set up on the local UCSB physical network, with Kubernetes services to build a network overlay on top.

## Physical network

Virtual machine based hosts have two network devices, one for the public UCSB subnet (128.111.85.0/24), and the other for the private Ceph subnet (10.0.3.0/24).

## Kubernetes Overlay network with Calico

Each pod in the kubernetes cluster gets its own IP address from the kubernetes network provider. We are currently using Calico...
