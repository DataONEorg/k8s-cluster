
# Ceph CSI CephFS

Back to: [Ceph-CSI](./Ceph-CSI.md)

The [Ceph Container Storage Interface (CSI) driver](https://github.com/ceph/ceph-csi) for Ceph Rados Block Device (RBD) and Ceph File System (CephFS) can be used to provide Ceph storage to applications running on k8s. 

## Provisioning Static CephFS Volumes

Each CephFS subvolume will correspond to a k8s persistent volume (PV). Because the ceph-csi cephfs plugin is being used, this PV can be mounted RWX, meaning that the PV can be mounted for write access by multiple k8s pods on multiple nodes.

Directions for manually creating the CephFS subvolumes are shown [here](https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/cephfs.md#commands-used-to-create-cephfs-subvolumes-on-the-dataone-ceph-cluter-ceph-15).

Once a ceph subvolume has been created, and the ceph-cis cephfs plugin has been started, it can be mounted as a k8s PV. 

Here is the example PV manifest, `cephfs-static-pv.yaml`:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cephfs-static-pv
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 1Gi
  csi:
    driver: cephfs.csi.ceph.com
    nodeStageSecretRef:
      # node stage secret name
      name: csi-cephfs-secret
      # node stage secret namespace where above secret is created
      namespace: ceph-csi-cephfs
    volumeAttributes:
      # Required options from storageclass parameters need to be added in volumeAttributes
      "clusterID": <clusterId>
      "fsName": "cephfs"
      "staticVolume": "true"
      "rootPath": /volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856
    # volumeHandle can be anything, need not to be same
    # as PV name or volume name. keeping same for brevity
    volumeHandle: cephfs-static-pv
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
```

This PV is created with the command:

```
kubectl create -f cephfs-static-pv.yaml
```

The PV can be inspected with the command:

```
kubectl describe pv cephfs-static-pv
```

The CephFS subvolume can be mounted by Linux, so that it can be accessed via the Linux command line. This may be useful in order to place files on the subvolume that will be used but not created by applications, such as configuration and data files. A sample command to mount a ceph subvolume:

```
sudo mount -t ceph 10.0.3.197:6789,10.0.3.223:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789:/volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856 /mnt/k8sdevsubvol -o name=k8sdevsubvoluser,secretfile=/etc/ceph/k8sdevsubvoluser.secret
```

It is not necessary to mount the subvolume with this Linux command in order for Ceph-CSI to access it.

## Persistent Volume Claim

The persistent volume claim (PVC) makes the PV available to a pod, and is created in a particular namespace. Here is an example, `cephfs-static-pvc.yaml`:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-static-pvc
  #namespace: ceph-csi-cephfs
  namespace: default
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  # volumeName should be same as PV name
  volumeName: cephfs-static-pv
```

The PVC is created with the command:

```
kubectl create -f cephfs-static-pvc.yaml
```

This can be inspected with the command:

```
kubectl describe pvc cephfs-static-pvc -n default
```

## Using The PVC

Here is an example of using the PVC from a Deployment, with the file `busybox.yaml`:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: default
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
          - name: cephfs-static-pv
            mountPath: /var/lib/www/html
      volumes:
        - name: cephfs-static-pv
          persistentVolumeClaim:
            claimName: cephfs-static-pvc
            readOnly: false
```


## Troubleshooting

If it ever occurs that a PV can't be unmounted after stoping ceph-csi, follow the directions from https://github.com/kubernetes/kubernetes/issues/77258. For example, if the PV name is cephfs-static-pv, for example:

```
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pvc cephfs-static-pvc -p '{"metadata":{"finalizers":null}}'
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pod pod/busybox-68df577cd8-s9x8w -p '{"metadata":{"finalizers":null}}'
```

