
# Ceph CSI RBD

Back to: [Ceph-CSI](./Ceph-CSI.md)

## Provisioning Dynamic Volumes with Ceph CSI RBD
### Storage Class

Dynamically provisioned PVs use the [csi-rbd-sc storageclass](https://github.com/DataONEorg/k8s-cluster/blob/main/storage/Ceph/Ceph-CSI.md#ceph-csi-rbd-dynamic-provisioning) on both k8s-dev and k8s-prod. 

### Persistent Volume Claim

Create PVC `ceph-rbd-pvc-test-1.yaml`:

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-rbd-pvc-test-1
  namespace: nick
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
```console
$ kubectl create -f ceph-rbd-pvc-test-1.yaml
```

When the PVC is created, the PV will be created dynamically by ceph-csi, with the volume size specified in the PVC manifest.

### Using The Persistent Volume Claim

After the SC and PVC have been created, pods can reference the PVC. When the pod is started, the Ceph-CSI driver is accessed and an RBD image is dynamically created for the pod. Here is an example pod that accesses the PVC, `busybox.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: nick
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
            claimName: ceph-rbd-pvc-test-1
            readOnly: false
```

The deployment is started with the command:

```console
$ kubectl create -f busybox.yaml
```

The storage class shown previously was created with the option `allowVolumeExpansion: true`. This allows the PV to be dynamically resized by first editing the PVC manifest file and changing the requested storage. For example, changing `storage: 10Gi` to `storage: 20Gi` in the PVC example above. Once this is done, enter the command:

```console
$ kubectl apply -f ceph-rbd-pvc.yaml
```

The volume can be expanded with this method while the deployment is running, i.e. it is not necessary to stop the deployment, resize the PV, then restart the deployment.

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

```yaml
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

```console
$ kubectl get pvc -A
```


