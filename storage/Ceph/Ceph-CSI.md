
# Ceph CSI

Up to: [Storage provisioning](../storage.md)

The [Ceph Container Storage Interface](https://github.com/ceph/ceph-csi) (CSI) driver for Ceph Rados Block Device (RBD) and Ceph File System (CephFS) can be used to provide Ceph storage to applications running on k8s. 

The Ceph CSI driver can provision static or dynamic Persistent Volumes (PV) for either RADOS Block Devices (RBD) or Ceph File System (CephFS) volumes.

A separate driver is required for RBD and CephFS, which can be installed using Helm.

Note that accessing RBD images with Ceph CSI currently does not allow multiple k8s pods to access the same storage in RWX (read write many) mode.

## Installing Ceph CSI RBD Plugin

Ceph CSI RBD helm installation information can be found [here](https://github.com/ceph/ceph-csi/blob/devel/charts/ceph-csi-rbd/README.md).

Command line options to helm supply most of the information that is needed for the installation. Two items that need to be manually created and installed befor the helm installatin are the `secret.yaml`, and `csi-config-map.yaml` files.

Here is an example `csi-config-map.yaml` file:

```
---
# This is a sample configmap that helps define a Ceph cluster configuration
# as required by the CSI plugins.
apiVersion: v1
kind: ConfigMap
# The <cluster-id> is used by the CSI plugin to uniquely identify and use a
# Ceph cluster, the value MUST match the value provided as `clusterID` in the
# StorageClass
# The <MONValue#> fields are the various monitor addresses for the Ceph cluster
# identified by the <cluster-id>
# If a CSI plugin is using more than one Ceph cluster, repeat the section for
# each such cluster in use.
# To add more clusters or edit MON addresses in an existing configmap, use
# the `kubectl replace` command.
# The <rados-namespace> is optional and represents a radosNamespace in the pool.
# If any given, all of the rbd images, snapshots, and other metadata will be
# stored within the radosNamespace.
# NOTE: The given radosNamespace must already exists in the pool.
# NOTE: Make sure you don't add radosNamespace option to a currently in use
# configuration as it will cause issues.
# The field "cephFS.subvolumeGroup" is optional and defaults to "csi".
# NOTE: Changes to the configmap is automatically updated in the running pods,
# thus restarting existing pods using the configmap is NOT required on edits
# to the configmap.
data:
  config.json: |-
    [
      {
        "clusterID": <cluster id from ceph>,
        "monitors": [
          "10.0.3.197:6789",
          "10.0.3.207:6789",
          "10.0.3.214:6789",
          "10.0.3.222:6789",
          "10.0.3.223:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
  namespace: ceph-csi-rbd
```

The Ceph cluster id and monitor addresses can be obtained with the command:

```
sudo ceph -n client.k8sdev --keyring=/etc/ceph/ceph.client.k8sdev.keyring mon dump
```

This example shows the required command for the DataONE k8s development cluster only. Appropriate values must be substituted for the production cluster when installing there.

The `secret.yaml` file contains the ceph storage cluster login credentials needed for ceph-csi to mount Ceph RBD images that are statically provisioned, or to create RBD images for dynamically provisioned voluems. For statically provisioned PVs, RBD images are created manually with the Linux `ceph` utility.

The `userId` and `userKey` values provide the needed authorization for this. These values can be found in the /etc/ceph directory of the k8s control nodes.

```
---
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: default
stringData:
  # Required for statically provisioned volumes
  userID: k8sdevrbd
  userKey: <user key from /etc/helm>

  # Required for dynamically provisioned volumes
  #adminID: <plaintext ID>
  #adminKey: <Ceph auth key corresponding to ID above>
```

To install the RBD plugin:

```
helm repo add ceph-csi https://ceph.github.io/csi-charts
kubectl create namespace "ceph-csi-rbd"
kubectl create -f secret.yaml
kubectl create -f csi-config-map.yaml

helm install "ceph-csi-rbd" ceph-csi/ceph-csi-rbd \
  --version 3.4.0 \
  --namespace "ceph-csi-rbd" \
  --set configMapName=ceph-csi-rbd\
  --set rbac.create=true \
  --set serviceAccounts.nodeplugin.create=true \
  --set serviceAccounts.provisioner.create=true \
  --set configMapName=ceph-csi-config \
  --set externallyManagedConfigmap=true \
  --set nodeplugin.name=csi-cephfsplugin \
  --set logLevel=5 \
  --set nodeplugin.registrar.image.tag="v2.2.0" \
  --set nodeplugin.plugin.image.tag="v3.4.0" \
  --set secret.create=false \
  --set secret.name=ceph-csi-rbd/csi-cephfs-secret \
  --set storageClass.create=false
```

The installation can be checked with the command:

```
helm status "ceph-csi-rbd" -n ceph-csi-rbd
```

The plugin can be stopped and uninstalled with the command:

```
helm uninstall "ceph-csi-rbd" --namespace "ceph-csi-rbd"
```

An example of using RBD based storage with k8s is provided [here](./Ceph-CSI-rbd.md)

## Installing Ceph CSI CephFS Plugin

Ceph CSI CephFS helm installation instructions can be found [here](https://github.com/ceph/ceph-csi/tree/devel/charts/ceph-csi-cephfs#readme).
Command line options to helm supply most of the information that is needed for the installation. Two items that need to be manually created and installed are the `secret.yaml`, and `csi-config-map.yaml` files.

The `secret.yaml` file contains the ceph storage cluster login credentials needed for ceph-csi to mount CephFS subvolumes that are statically provisioned. These CephFS subvolumes must be created manually with the Linux `ceph` utility before they can be accessed by ceph-csi.

The `userId` and `userKey` values provide the needed authorization for this. Note that for dynamically provisioned (ceph-csi provisions them) CephFS volumes and subvolumes, the `adminId` and `adminKey` values are required.

Currently for DataONE, only statically provisioned CephFS subvolumes are used. Also, currently this ceph-csi feature is only in Alpha release state, so is not ready for production use. Please refer to the [Ceph-CSI Support Matrix](https://github.com/ceph/ceph-csi#support-matrix) for more information.

```
---
apiVersion: v1
kind: Secret
metadata:
  name: csi-cephfs-secret
  namespace: default
stringData:
  # Required for statically provisioned volumes
  userID: k8sdevsubvoluser
  userKey: <Ceph auth key corresponding to ID above from /etc/ceph>
```

Here is an example `csi-config-map.yaml` file:

```
---
# This is a sample configmap that helps define a Ceph cluster configuration
# as required by the CSI plugins.
apiVersion: v1
kind: ConfigMap
# The <cluster-id> is used by the CSI plugin to uniquely identify and use a
# Ceph cluster, the value MUST match the value provided as `clusterID` in the
# StorageClass
# The <MONValue#> fields are the various monitor addresses for the Ceph cluster
# identified by the <cluster-id>
# If a CSI plugin is using more than one Ceph cluster, repeat the section for
# each such cluster in use.
# To add more clusters or edit MON addresses in an existing configmap, use
# the `kubectl replace` command.
# The <rados-namespace> is optional and represents a radosNamespace in the pool.
# If any given, all of the rbd images, snapshots, and other metadata will be
# stored within the radosNamespace.
# NOTE: The given radosNamespace must already exists in the pool.
# NOTE: Make sure you don't add radosNamespace option to a currently in use
# configuration as it will cause issues.
# The field "cephFS.subvolumeGroup" is optional and defaults to "csi".
# NOTE: Changes to the configmap is automatically updated in the running pods,
# thus restarting existing pods using the configmap is NOT required on edits
# to the configmap.
data:
  config.json: |-
    [
      {
        "clusterID": <cluster id from ceph>,
        "monitors": [
          "10.0.3.197:6789",
          "10.0.3.207:6789",
          "10.0.3.214:6789",
          "10.0.3.222:6789",
          "10.0.3.223:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
  namespace: ceph-csi-rbd
```

To install the CephFS plugin:

```
kubectl create namespace ceph-csi-cephfs
kubectl create -f secret.yaml
kubectl create -f csi-config-map.yaml
helm install "ceph-csi-cephfs" ceph-csi/ceph-csi-cephfs \
  --version 3.4.0 \
  --namespace "ceph-csi-cephfs" \
  --set configMapName=ceph-csi-config \
  --set rbac.create=true \
  --set serviceAccounts.nodeplugin.create=true \
  --set serviceAccounts.provisioner.create=true \
  --set configMapName=ceph-csi-config \
  --set externallyManagedConfigmap=true \
  --set nodeplugin.name=csi-cephfsplugin \
  --set logLevel=5 \
  --set nodeplugin.registrar.image.tag="v2.2.0" \
  --set nodeplugin.plugin.image.tag="v3.4.0" \
  --set secret.create=false \
  --set secret.name=ceph-csi-cephfs/csi-cephfs-secret \
  --set storageClass.create=false
```

The status of the installation can be checked with the command:

```
helm status "ceph-csi-cephfs" --namespace "ceph-csi-cephfs"
```

The plugin can be stopped and uninstalled with the command:

```
helm uninstall "ceph-csi-cephfs" --namespace "ceph-csi-cephfs"
```

An example of using CephFS based storage with k8s is provided [here](./Ceph-CSI-cephfs.md)
