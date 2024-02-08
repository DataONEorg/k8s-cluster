# DataONE Kubernetes Cluster

Documentation on the DataONE Kubernetes cluster. This repository contains operational documentation on the cluster, as well as default configuration files for the deployments.

Documentation is organized into an overview, and then separate config files and documentation for each of the main configured services provided by he cluster. Documentation of the specific services operated on the cluster (e.g., metadig, dataone-api, etc.) is in their respective repositories.

## [Cluster Overview](./cluster-overview.md)
- [Overview of the DataONE Kubernetes Cluster](./cluster-overview.md#Overview-of-the-DataONE-Kubernetes-Cluster)
- [High Availability and Fault Tolerance](./cluster-overview.md#High-Availability-and-Fault-Tolerance)

## [Cluster Administration](./admin/admin.md)
- [Rebooting](./admin/admin.md#Rebooting)
- [Adding a Node](./admin/admin.md#Adding-a-node)
- [Assigning Pods to Nodes](./admin/admin.md#Assigning-Pods-to-Nodes)

## [Managing Let's Encrypt Certificates With cert-manager](/authentication/LetsEncrypt.md)
- [Installing cert-manager](./authentication/LetsEncrypt.md#Installing-cert-manager)
- [Configuring cert-manager](./authentication/LetsEncrypt.md#Configuring-cert-manager)
- [Configure and Deploy Ingress resource](./authentication/LetsEncrypt.md#Configure-and-Deploy-Ingress-resource)

## [Application Authorization](./authorization/authorization.md)
- [Create The kubectl Configuration File](./authorization/authorization.md#Create-The-kubectl-Configuration-File)
- [Grant Additional Privileges To The serviceAccount](./authorization/authorization.md#Grant-Additional-Privileges-To-The-serviceAccount)
- [References](./authorization/authorization.md#References)

## [Control Plane Configuration](./control-plane/control-plane.md)
- [Control plane high availability](./control-plane/control-plane.md#Control-plane-high-availability)
- [Control Plane Configuration](./control-plane/control-plane.md#Control-Plane-Configuration)
- [Load Balancer](./control-plane/control-plane.md#Load-Balancer)
- [etcd service](./control-plane/control-plane.md#etcd-service)
- [Ingress Controller](./control-plane/control-plane.md#Ingress-Controller)
  - [Installation](./control-plane/control-plane.md#Installation)
  - [Configuration](./control-plane/control-plane.md#Configuration)
    - [Ingress Class](./control-plane/control-plane.md#Ingress-Class)
    - [Ingress](./control-plane/control-plane.md##Ingress)

## [Networking Configuration](./network/network.md)
- [Physical network](./network/network.md#Physical-network)
- [Kubernetes Overlay network with Calico](./network/network.md#Kubernetes-Overlay-network-with-Calico)

## [Storage Provisioning](./storage/storage.md)
- [Persistent Disk Storage For Applications](./storage/storage.md#Persistent-Disk-Storage-For-Applications)
  - [Persistent Volumes](./storage/storage.md#Persistent-Volumes)
  - [Persistent Volume Claim](./storage/storage.md#Persistent-Volume-Claim)
  - [Statically Provisioned Persistent Volumes](./storage/storage.md#Statically-Provisioned-Persistent-Volumes)
  - [Dynamically Provisioned Persistent Volumes](./storage/storage.md#Dynamically-Provisioned-Persistent-Volumes)
- [Ceph-based Volumes](./storage/storage.md#Ceph-based-Volumes)
- [Data Recovery](./storage/storage.md#Data-Recovery)

### [Ceph CSI](./storage/Ceph/Ceph-CSI.md#)
- [Installing Ceph CSI RBD Plugin](./storage/Ceph/Ceph-CSI.md#Installing-Ceph-CSI-RBD-Plugin)
- [Installing Ceph CSI CephFS Plugin](./storage/Ceph/Ceph-CSI.md#Installing-Ceph-CSI-CephFS-Plugin)
- [Important Notes on Secrets and Credentials](./Ceph-CSI.md#important-notes-on-secrets-and-credentials)

#### [Ceph CSI CephFS](./storage/Ceph/Ceph-CSI-CephFS.md)
- [Provisioning Static CephFS Volumes](./storage/Ceph/Ceph-CSI-CephFS.md#Provisioning-Static-CephFS-Volumes)
- [Persistent Volume Claim](./storage/Ceph/Ceph-CSI-CephFS.md#Persistent-Volume-Claim)
- [Using The PVC](./storage/Ceph/Ceph-CSI-CephFS.md#Using-The-PVC)
- [Troubleshooting](./storage/Ceph/Ceph-CSI-CephFS.md#Troubleshooting)

#### [Ceph CSI RBD](./storage/Ceph/Ceph-CSI-RBD.md)
- [Provisioning Static Volumes with Ceph CSI RBD](./storage/Ceph/Ceph-CSI-RBD.md#Provisioning-Static-Volumes-with-Ceph-CSI-RBD)
  - [Persistent Volume](./storage/Ceph/Ceph-CSI-RBD.md#Persistent-Volume)
  - [List all pools](./storage/Ceph/Ceph-CSI-RBD.md#List-all-pools)
  - [Persistent Volume Claim](./storage/Ceph/Ceph-CSI-RBD.md#Persistent-Volume-Claim)
- [Provisioning Dynamic Volumes with Ceph CSI RBD](./storage/Ceph/Ceph-CSI-RBD.md#Provisioning-Dynamic-Volumes-with-Ceph-CSI-RBD)
  - [Storage Class](./storage/Ceph/Ceph-CSI-RBD.md#Storage-Class)
  - [Persistent Volume Claim](./storage/Ceph/Ceph-CSI-RBD.md#Persistent-Volume-Claim)
  - [Using The Persistent Volume Claim](./storage/Ceph/Ceph-CSI-RBD.md#Using-The-Persistent-Volume-Claim)

## [Data Recovery](./storage/data-recovery.md#Data-Recovery)
- [Data Recovery For RBD Based PVs](./storage/data-recovery.md#Data-Recovery-For-RBD-Based-PVs)
- [Data Recovery For CephFS Based PVs](./storage/data-recovery.md#Data-Recovery-For-CephFS-Based-PVs)

[![dataone_footer](https://user-images.githubusercontent.com/6643222/162324180-b5cf0f5f-ae7a-4ca6-87c3-9733a2590634.png)](https://www.dataone.org)
