
# Ceph CSI RBD

Back to: [Ceph-CSI](./Ceph-CSI.md)

## Provisioning Static Volumes with Ceph CSI RBD

The Ceph CSI k8s driver can provision k8s persistent volumes (PVs) as RBD images. With static provisioning, the Ceph RBD image must be created manually before it can be accessed by Ceph-CSI.

Note that accessing Ceph storage in this way currently does not allow multiple k8s pods to access the same storage in RWX (read write many) mode. 

### Persistent Volume

Here is the example PV manifest, `rbd-static-pv.yaml`:


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
sudo ceph --id k8sdev mon dump
```

Ceph pools can be listed with the command:

```
# List all pools
sudo ceph --id k8sdev osd lspools
```

Images within a pool can be listed with the command:

```
sudo rbd --id k8sdevrbd ls k8sdev-pool-ec42-metadata

```

### Persistent Volume Claim

The persistent volume claim (PVC) makes the PV available to a pod, and is created in a particular namespace. Here is an example, `rbd-static-pvc.yaml`:

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
  volumeMode: Filesystem/
  # volumeName should be same as PV name
  volumeName: ceph-rbd-static-pv
```

To view all PVCs, run:

```
kubectl get pvc -A
```

## Provisioning Dynamic Volumes with Ceph CSI RBD
### Storage Class

For dynamically provisioned PVs, creating a PV manifest is not required. Instead a Storage Class (SC) description is created. 

Here is an example RBD SC manifest `csi-rbd-sc.yaml`:

```
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
   dataPool: k8s-pool-ec42-data

   # (required) Ceph pool into which the RBD image shall be created
   # eg: pool: rbdpool
   pool: k8s-pool-ec42-metadata

   # Deprecated: Set thickProvision to true if you want RBD images to be fully
   # allocated on creation (thin provisioning is the default).
   # thickProvision: "false"

   # (required) RBD image features, CSI creates image with image-format 2
   # CSI RBD currently supports `layering`, `journaling`, `exclusive-lock`
   # features. If `journaling` is enabled, must enable `exclusive-lock` too.
   # imageFeatures: layering,journaling,exclusive-lock
   imageFeatures: layering

   # (optional) Specifies whether to try other mounters in case if the current
   # mounter fails to mount the rbd image for any reason. True means fallback
   # to next mounter, default is set to false.
   # Note: tryOtherMounters is currently useful to fallback from krbd to rbd-nbd
   # in case if any of the specified imageFeatures is not supported by krbd
   # driver on node scheduled for application pod launch, but in the future this
   # should work with any mounter type.
   # tryOtherMounters: false

   # (optional) mapOptions is a comma-separated list of map options.
   # For krbd options refer
   # https://docs.ceph.com/docs/master/man/8/rbd/#kernel-rbd-krbd-options
   # For nbd options refer
   # https://docs.ceph.com/docs/master/man/8/rbd-nbd/#options
   # mapOptions: lock_on_read,queue_depth=1024

   # (optional) unmapOptions is a comma-separated list of unmap options.
   # For krbd options refer
   # https://docs.ceph.com/docs/master/man/8/rbd/#kernel-rbd-krbd-options
   # For nbd options refer
   # https://docs.ceph.com/docs/master/man/8/rbd-nbd/#options
   # unmapOptions: force

   # The secrets have to contain Ceph credentials with required access
   # to the 'pool'.
   csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi-rbd
   csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi-rbd
   csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
   csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi-rbd

   # (optional) Specify the filesystem type of the volume. If not specified,
   # csi-provisioner will set default as `ext4`.
   csi.storage.k8s.io/fstype: ext4

   # (optional) uncomment the following to use rbd-nbd as mounter
   # on supported nodes
   # mounter: rbd-nbd

   # (optional) ceph client log location, eg: rbd-nbd
   # By default host-path /var/log/ceph of node is bind-mounted into
   # csi-rbdplugin pod at /var/log/ceph mount path. This is to configure
   # target bindmount path used inside container for ceph clients logging.
   # See docs/rbd-nbd.md for available configuration options.
   # cephLogDir: /var/log/ceph

   # (optional) ceph client log strategy
   # By default, log file belonging to a particular volume will be deleted
   # on unmap, but you can choose to just compress instead of deleting it
   # or even preserve the log file in text format as it is.
   # Available options `remove` or `compress` or `preserve`
   # cephLogStrategy: remove

   # (optional) Prefix to use for naming RBD images.
   # If omitted, defaults to "csi-vol-".
   # volumeNamePrefix: "foo-bar-"

   # (optional) Instruct the plugin it has to encrypt the volume
   # By default it is disabled. Valid values are "true" or "false".
   # A string is expected here, i.e. "true", not true.
   # encrypted: "true"

   # (optional) Use external key management system for encryption passphrases by
   # specifying a unique ID matching KMS ConfigMap. The ID is only used for
   # correlation to configmap entry.
   # encryptionKMSID: <kms-config-id>

   # Add topology constrained pools configuration, if topology based pools
   # are setup, and topology constrained provisioning is required.
   # For further information read TODO<doc>
   # topologyConstrainedPools: |
   #   [{"poolName":"pool0",
   #     "dataPool":"ec-pool0" # optional, erasure-coded pool for data
   #     "domainSegments":[
   #       {"domainLabel":"region","value":"east"},
   #       {"domainLabel":"zone","value":"zone1"}]},
   #    {"poolName":"pool1",
   #     "dataPool":"ec-pool1" # optional, erasure-coded pool for data
   #     "domainSegments":[
   #       {"domainLabel":"region","value":"east"},
   #       {"domainLabel":"zone","value":"zone2"}]},
   #    {"poolName":"pool2",
   #     "dataPool":"ec-pool2" # optional, erasure-coded pool for data
   #     "domainSegments":[
   #       {"domainLabel":"region","value":"west"},
   #       {"domainLabel":"zone","value":"zone1"}]}
   #   ]

reclaimPolicy: Retain
allowVolumeExpansion: true
```

The storage class is created with the command:
```
kubectl create -f csi-rbd-sc.yaml
```

### Persistent Volume Claim

Once the SC has been created, a PVC can be created, for example `ceph-rbd-pvc.yaml`:


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

Create the PVC with the command:
```
kubectl create -f ceph-rbd-pvc.yaml
```

When the PVC is created, the PV will be created dynamically by ceph-csi, with the volume size specified in the PVC manifest.

### Using The Persistent Volume Claim

After the SC and PVC have been created, pods can reference the PVC. When the pod is started, the Ceph-CSI driver is accessed and an RBD image is dynamically created for the pod. Here is an example pod that accesses the PVC, `busybox.yaml`:

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

The deployment is started with the command:

```
kubectl create -f busybox.yaml
```

The storage class shown previously was created with the option `allowVolumeExpansion: true`. This allows the PV to be dynamically resized by first editing the PVC manifest file and changing the requested storage. For example, changing `storage: 10Gi` to `storage: 20Gi` in the PVC example above. Once this is done, enter the command:

```
kubectl apply -f ceph-rbd-pvc.yaml
```

The volume can be expanded with this method while the deployment is running, i.e. it is not necessary to stop the deployment, resize the PV, then restart the deployment.
