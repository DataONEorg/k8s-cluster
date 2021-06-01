# Networking Configuration

Up to: [DataONE Cluster Overview](../cluster-overview.md)

Networking for the Kubernetes cluster is set up on the local UCSB physical network, with Kubernetes services to build a network overlay on top.

## Physical network

Describe host-networking...

## Kubernetes Overlay network with Calico

Each pod in the kubernetes cluster gets its own IP address from the kubernetes network provider. We are currently using Calico...
