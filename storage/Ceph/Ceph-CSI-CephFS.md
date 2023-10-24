
# Ceph CSI CephFS

Back to: [Ceph-CSI](./Ceph-CSI.md)

The [Ceph Container Storage Interface (CSI) driver](https://github.com/ceph/ceph-csi) for Ceph Rados Block Device (RBD) and Ceph File System (CephFS) can be used to provide Ceph storage to applications running on k8s. 

## Provisioning Static CephFS Volumes

Each CephFS subvolume will correspond to a k8s persistent volume (PV). Because the ceph-csi cephfs plugin is being used, this PV can be mounted RWX, meaning that the PV can be mounted for write access by multiple k8s pods on multiple nodes.

Directions for manually creating the CephFS subvolumes are shown [here](https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/cephfs.md#commands-used-to-create-cephfs-subvolumes-on-the-dataone-ceph-cluter-ceph-15).

Once a ceph subvolume has been created, and the ceph-csi cephfs plugin has been started, it can be mounted as a k8s PV. 

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
      "clusterID": "8aa4d4a0-a209-11ea-baf5-ffc787bfc812:
      "fsName": "cephfs"
      "staticVolume": "true"
      "rootPath": /volumes/k8ssubvolgroup/k8ssubvol/af348873-2be8-4a99-b1c1-ed2c80fe098b
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
sudo mount -t ceph 10.0.3.197:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8ssubvolgroup/k8ssubvol/af348873-2be8-4a99-b1c1-ed2c80fe098b \
   /mnt/k8ssubvol -o name=k8ssubvoluser,secretfile=/etc/ceph/k8ssubvoluser.secret
```

It is not necessary to mount the subvolume with this Linux command in order for Ceph-CSI to access it.

## Persistent Volume Claim

The persistent volume claim (PVC) makes the PV available to a pod, and is created in a particular namespace. Here is an example, `cephfs-static-pvc.yaml`:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-static-pvc
  namespace: ceph-csi-cephfs
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
  namespace: ceph-csi-cephfs
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

1. If a PV can't be unmounted after stopping ceph-csi, follow the directions from https://github.com/kubernetes/kubernetes/issues/77258. For example, if the PV name is `cephfs-static-pv`:

```console
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pvc cephfs-static-pvc -p '{"metadata":{"finalizers":null}}'
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pod pod/busybox-68df577cd8-s9x8w -p '{"metadata":{"finalizers":null}}'
```

2. If you see an error similar to this:

```console
  Warning  FailedMount  14s   kubelet   MountVolume.MountDevice failed for volume
"cephfs-metacatbrooke-metacat" : rpc error: code = Internal desc = an error (exit
status 32) occurred while running mount args: [-t ceph 10.0.3.197:6789,10.0.3.207:
6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8s-dev-metacatbrooke
-subvol-group/k8s-dev-metacatbrooke-subvol/59cad964-ce10-40f9-8242-983da3fd0ce3
/var/lib/kubelet/plugins/kubernetes.io/csi/pv/cephfs-metacatbrooke-metacat/globalmount
-o name=client.k8s-dev-metacatbrooke-subvol-user,secretfile=/tmp/csi/keys/keyfile-370004680,
mds_namespace=cephfs,_netdev] stderr: mount error: no mds server is up or the cluster is laggy
```

...the message `no mds server is up or the cluster is laggy` is potentially misleading. It is more likely that the `userID` is missing or incorrect, in your `secret.yaml` file. See [Ceph CSI - Important Notes](https://github.com/DataONEorg/k8s-cluster/blob/main/storage/Ceph/Ceph-CSI.md#important-notes). 



## Provisioning Dynamic CephFS Volumes

Dynamic CephFS Volumes can be provisioned using the [csi-cephfs-sc storageclass](https://github.com/DataONEorg/k8s-cluster/blob/main/storage/Ceph/Ceph-CSI.md#ceph-csi-cephfs-dynamic-provisioning) on both K8s-prod and K8s-dev clusters.

 
Here is an example PVC `csi-cephfs-pvc-test-12.yaml` creating a dynamic CephFS volume:

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-cephfs-pvc-test-12
  namespace: nick
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: csi-cephfs-sc
```

Create the PVC with the command:

```console
kubectl create -f csi-cephfs-pvc-test-12.yaml
```

Then check that is has been successfully provisioned:

```console
$ kubectl get pvc -n nick csi-cephfs-pvc-test-12
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
csi-cephfs-pvc-test-12   Bound    pvc-91690627-43bd-44c4-81d5-50b6901fda45   10Gi       RWX            csi-cephfs-sc   33m

$ kubectl describe pvc -n nick csi-cephfs-pvc-test-12
Name:          csi-cephfs-pvc-test-12
Namespace:     nick
StorageClass:  csi-cephfs-sc
Status:        Bound
Volume:        pvc-91690627-43bd-44c4-81d5-50b6901fda45
Labels:        <none>
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: cephfs.csi.ceph.com
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      10Gi
Access Modes:  RWX
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type    Reason                 Age   From                                                                                                   Message
  ----    ------                 ----  ----                                                                                                   -------
  Normal  Provisioning           37m   cephfs.csi.ceph.com_ceph-csi-cephfs-provisioner-5f465c8b64-nqxqg_edce56f9-51eb-4371-be4f-a8b73498d3ae  External provisioner is provisioning volume for claim "nick/csi-cephfs-pvc-test-12"
  Normal  ExternalProvisioning   37m   persistentvolume-controller                                                                            waiting for a volume to be created, either by external provisioner "cephfs.csi.ceph.com" or manually created by system administrator
  Normal  ProvisioningSucceeded  37m   cephfs.csi.ceph.com_ceph-csi-cephfs-provisioner-5f465c8b64-nqxqg_edce56f9-51eb-4371-be4f-a8b73498d3ae  Successfully provisioned volume pvc-91690627-43bd-44c4-81d5-50b6901fda45
```

You can find the full CephFS path name using the PVC Volume name:

```console
$ kubectl get pv pvc-91690627-43bd-44c4-81d5-50b6901fda45 -o yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: cephfs.csi.ceph.com
  creationTimestamp: "2023-10-24T16:28:38Z"
  finalizers:
  - kubernetes.io/pv-protection
  name: pvc-91690627-43bd-44c4-81d5-50b6901fda45
  resourceVersion: "368045407"
  uid: b5f4229b-181e-4fc8-890c-92b30f2e1cbc
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 10Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: csi-cephfs-pvc-test-12
    namespace: nick
    resourceVersion: "368045401"
    uid: 91690627-43bd-44c4-81d5-50b6901fda45
  csi:
    controllerExpandSecretRef:
      name: csi-cephfs-secret
      namespace: default
    driver: cephfs.csi.ceph.com
    nodeStageSecretRef:
      name: csi-cephfs-node-secret
      namespace: default
    volumeAttributes:
      clusterID: 8aa4d4a0-a209-11ea-baf5-ffc787bfc812
      csi.storage.k8s.io/pv/name: pvc-91690627-43bd-44c4-81d5-50b6901fda45
      csi.storage.k8s.io/pvc/name: csi-cephfs-pvc-test-12
      csi.storage.k8s.io/pvc/namespace: nick
      fsName: cephfs
      storage.kubernetes.io/csiProvisionerIdentity: 1698156357817-8081-cephfs.csi.ceph.com
      subvolumeName: k8s-dev-csi-vol-62fa67ca-728a-11ee-aac4-bea91be78439
      subvolumePath: /volumes/csi/k8s-dev-csi-vol-62fa67ca-728a-11ee-aac4-bea91be78439/0a55f930-96ac-4a7d-bf45-49e6ac61046b
      volumeNamePrefix: k8s-dev-csi-vol-
    volumeHandle: 0001-0024-8aa4d4a0-a209-11ea-baf5-ffc787bfc812-0000000000000001-62fa67ca-728a-11ee-aac4-bea91be78439
  mountOptions:
  - debug
  persistentVolumeReclaimPolicy: Delete
  storageClassName: csi-cephfs-sc
  volumeMode: Filesystem
status:
  phase: Bound
```




