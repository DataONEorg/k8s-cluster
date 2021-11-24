
# Ceph CSI CephFS

Back to: [Ceph](./Ceph.md)

## Provisioning Static Volumes with Ceph CSI RBD

### Persistent Volume 

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ceph-rbd-static-pv
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  csi:
    driver: rbd.csi.ceph.com
    fsType: ext4
    nodeStageSecretRef:
      # node stage secret name
      name: csi-rbd-secret
      # node stage secret namespace where above secret is created
      namespace: default
    volumeAttributes:
      # Required options from storageclass parameters need to be added in volumeAttributes
      "clusterID": <cluster id>
      "pool": "k8sdev-pool-ec42-metadata"
      "staticVolume": "true"
      "imageFeatures": "layering"
    # volumeHandle should be same as rbd image name
    volumeHandle: k8sdevtest
  persistentVolumeReclaimPolicy: Retain
  # The volumeMode can be either `Filesystem` or `Block` if you are creating Filesystem PVC it should be `Filesystem`, if you are creating Block PV you need to change it to `Block`
  volumeMode: Filesystem
```

The Ceph cluster id and monitors can be obtained with the command:

```
sudo ceph -n client.k8sdev --keyring=/etc/ceph/ceph.client.k8sdev.keyring mon dump
```

Ceph pools can be listed with the command:

```
# List all pools
sudo ceph -n client.k8sdev --keyring=/etc/ceph/ceph.client.k8sdev.keyring osd lspools
```

Images within a pool can be listed with the command:

```
sudo rbd -n client.k8sdevrbd --keyring=/etc/ceph/ceph.client.k8sdevrbd.keyring ls k8sdev-pool-ec42-metadata

```

### Persistent Volume Claim

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-rbd-static-pvc
  namespace: ceph-csi-rbd
spec:
  accessModes:
  # ReadWriteMany is only supported for Block PVC
  - ReadWriteMany
  #- ReadWriteOnce
  #- ReadWriteOncePod - not supported k8s v1.22.2
  resources:
    requests:
      storage: 1Gi
  # The volumeMode can be either `Filesystem` or `Block` if you are creating Filesystem PVC it should be `Filesystem`, if you are creating Block PV you need to change it to `Block`
  volumeMode: Filesystem
  # volumeName should be same as PV name
  volumeName: ceph-rbd-static-pv
```

## Provisioning Dynamic Volumes with Ceph CSI RBD
### Storage Class

```
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: csi-rbd-sc
provisioner: rbd.csi.ceph.com
# If topology based provisioning is desired, delayed provisioning of
# PV is required and is enabled using the following attribute
# For further information read TODO<doc>
# volumeBindingMode: WaitForFirstConsumer
parameters:
   # (required) String representing a Ceph cluster to provision storage from.
   # Should be unique across all Ceph clusters in use for provisioning,
   # cannot be greater than 36 bytes in length, and should remain immutable for
   # the lifetime of the StorageClass in use.
   # Ensure to create an entry in the configmap named ceph-csi-config, based on
   # csi-config-map-sample.yaml, to accompany the string chosen to
   # represent the Ceph cluster in clusterID below
   clusterID: 8aa4d4a0-a209-11ea-baf5-ffc787bfc812

   # (optional) If you want to use erasure coded pool with RBD, you need to
   # create two pools. one erasure coded and one replicated.
   # You need to specify the replicated pool here in the `pool` parameter, it is
   # used for the metadata of the images.
   # The erasure coded pool must be set as the `dataPool` parameter below.
   dataPool: k8sdev-pool-ec42-data

   # (required) Ceph pool into which the RBD image shall be created
   pool: k8sdev-pool-ec42-metadata

   # (required) RBD image features, CSI creates image with image-format 2
   # CSI RBD currently supports `layering`, `journaling`, `exclusive-lock`
   # features. If `journaling` is enabled, must enable `exclusive-lock` too.
   # imageFeatures: layering,journaling,exclusive-lock
   imageFeatures: layering

   # The secrets have to contain Ceph credentials with required access
   # to the 'pool'.
   csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi-rbd
   csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: default
   csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
   csi.storage.k8s.io/node-stage-secret-namespace: csi-rbd-secret

   # (optional) Specify the filesystem type of the volume. If not specified,
   # csi-provisioner will set default as `ext4`.
   csi.storage.k8s.io/fstype: ext4
   
reclaimPolicy: Retain
allowVolumeExpansion: false

```
### Persistent Volume Claim

```
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-rbd-pvc
  namespace: ceph-csi-rbd
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 10Gi
  storageClassName: csi-rbd-sc
```

### Using The Persistent Volume Claim

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: ceph-csi-rbd
spec:
  selector:
    matchLabels:
      app: busybox
  replicas: 1
  template:
    metadata:
      labels:
        app: busybox
    spec:
      containers:
      - name: busybox
        image: docker.io/busybox:1.29
        args: [sh, -c, 'sleep 9999999999']
        volumeMounts:
          - name: mypvc
            mountPath: /var/lib/www/html
      volumes:
        - name: mypvc
          persistentVolumeClaim:
            claimName: ceph-rbd-pvc
            readOnly: false
```