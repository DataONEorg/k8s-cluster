# Data Recovery

Back to: [Storage Provisioning](./storage.md)

It may become necessary to recover data from the Ceph Storage System if the persistent volumes (PV)s used by DataONE applications become unusable or are deleted.

DataONE is currently using RBD image based PVs that are dynamically provisioned and CephFS subvolume based PVs that are manually provisioned.

## Data Recovery For RBD Based PVs

### Determine the pod's PVC

If the affected pod is still running, determine the PVC that it is using. The test example is using a`busybox` deployment and is in the namespace `metadig`:

```
$ kubectl describe deployment busybox -n metadig
Name:                   busybox
Namespace:              metadig
CreationTimestamp:      Fri, 11 Feb 2022 12:37:45 -0800
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=busybox
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=busybox
  Containers:
   busybox:
    Image:      docker.io/busybox:1.29
    Port:       <none>
    Host Port:  <none>
    Args:
      sh
      -c
      sleep 9999999999
    Environment:  <none>
    Mounts:
      /var/lib/www/html from mypvc (rw)
  Volumes:
   mypvc:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  ceph-rbd-pvc-recovery-test
    ReadOnly:   false
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   busybox-9b5bc6757 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  14s   deployment-controller  Scaled up replica set busybox-9b5bc6757 to 1
```

The listing shows that the PVC name ("*ClaimName*") is `ceph-rbd-pvc-recovery-test`.

If the application is not running, the application manifest can be inspected for the PVC name. This is the application manifest used in this example:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: metadig
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
            claimName: ceph-rbd-pvc-recovery-test
            readOnly: false
```

### Determine the PV used by the PVC

Next, determine the PV that is being used by the PVC by listing all PVs currently active:

```
$ kubectl get pv -o wide
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS        CLAIM                                  STORAGECLASS   REASON   AGE     VOLUMEMODE
cephfs-dataone-solr-pv                     100Gi      RWX            Retain           Bound         dataone-solr/cephfs-dataone-solr-pvc                           3h36m   Filesystem
cephfs-gnis-pv                             75Gi       RWX            Retain           Bound         gnis/cephfs-gnis-pvc                                           99d     Filesystem
cephfs-metadig-pv                          50Gi       RWX            Retain           Bound         metadig/cephfs-metadig-pvc                                     99d     Filesystem
cephfs-slinky-pv                           50Gi       RWX            Retain           Bound         slinky/cephfs-slinky-pvc                                       99d     Filesystem
gnis-pv                                    75Gi       RWX            Retain           Terminating   gnis/gnis-pvc                          manual                  158d    Filesystem
pvc-05119da3-50cd-43aa-aa42-b7b32c1ffed2   50Gi       RWO            Retain           Bound         polder/polder-pvc-01                   csi-rbd-sc              58d     Filesystem
pvc-55d4c915-2e26-4d76-b777-f0808ac1d01f   50Gi       RWO            Retain           Terminating   polder/polder-pvc-02                   csi-rbd-sc              57d     Filesystem
pvc-e3f356de-bc2a-4381-a7d8-fd202203840e   10Gi       RWO            Retain           Terminating   metadig/ceph-rbd-pvc-recovery-test     csi-rbd-sc              4m2s    Filesystem
slinky-pv                                  75Gi       RWX            Retain           Released      slinky/slinky-pvc                      manual                  157d    Filesystem

```

This listing shows that the PV named `pvc-e3f356de-bc2a-4381-a7d8-fd202203840e` is being used by the PVC  `ceph-rbd-pvc-recovery-test` (see under the `CLAIM` column). 

This PV has the status `Terminating`, which means that the PV will be deleted once the app is no longer running and the PVC has been deleted. 

Note that because DataONE PVs are created with the reclaim policy of 'Retain', the pod's data on the RBD image will not be deleted when the PV is deleted.

### Locate the RBD image

Now that the PV name is known, the RBD image that was provisioned for and used by the PV can be found.

First find the RBD image name using the PV name:

```
$ kubectl describe pv pvc-e3f356de-bc2a-4381-a7d8-fd202203840e
Name:            pvc-e3f356de-bc2a-4381-a7d8-fd202203840e
Labels:          <none>
Annotations:     pv.kubernetes.io/provisioned-by: rbd.csi.ceph.com
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    csi-rbd-sc
Status:          Bound
Claim:           metadig/ceph-rbd-pvc-recovery-test
Reclaim Policy:  Retain
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        10Gi
Node Affinity:   <none>
Message:
Source:
    Type:              CSI (a Container Storage Interface (CSI) volume source)
    Driver:            rbd.csi.ceph.com
    FSType:            ext4
    VolumeHandle:      0001-0024-8aa4d4a0-a209-11ea-baf5-ffc787bfc812-000000000000000d-60d4a0cd-8b7e-11ec-89be-96b0610b4778
    ReadOnly:          false
    VolumeAttributes:      clusterID=8aa4d4a0-a209-11ea-baf5-ffc787bfc812
                           csi.storage.k8s.io/pv/name=pvc-e3f356de-bc2a-4381-a7d8-fd202203840e
                           csi.storage.k8s.io/pvc/name=ceph-rbd-pvc-recovery-test
                           csi.storage.k8s.io/pvc/namespace=metadig
                           dataPool=k8sdev-pool-ec42-data
                           imageFeatures=layering
                           imageName=csi-vol-60d4a0cd-8b7e-11ec-89be-96b0610b4778
                           journalPool=k8sdev-pool-ec42-metadata
                           pool=k8sdev-pool-ec42-metadata
                           storage.kubernetes.io/csiProvisionerIdentity=1644586826522-8081-rbd.csi.ceph.com
Events:                <none>
```

The RBD image name is shown in the line "`imageName=csi-vol-60d4a0cd-8b7e-11ec-89be-96b0610b4778`".

If the PV has already been deleted, the list of RBD images that are provisioned within this Ceph pool can be listed:

```

$ sudo rbd --id k8sdevrbd -p k8sdev-pool-ec42-metadata ls
csi-vol-60d4a0cd-8b7e-11ec-89be-96b0610b4778
csi-vol-7f858bfa-8083-11ec-89be-96b0610b4778
csi-vol-8457c064-3e91-11ec-89be-96b0610b4778
csi-vol-aafad4cb-40c0-11ec-89be-96b0610b4778
csi-vol-b98fea25-5df1-11ec-bfff-527f42b0f619
csi-vol-bfb110d1-8088-11ec-89be-96b0610b4778
csi-vol-c44dded1-8085-11ec-89be-96b0610b4778
csi-vol-df92f876-8a0a-11ec-89be-96b0610b4778
csi-vol-e33bc64d-3e8e-11ec-89be-96b0610b4778
csi-vol-ea3d956c-5dda-11ec-bfff-527f42b0f619
csi-vol-fc000852-7fcc-11ec-89be-96b0610b4778
```

The Ceph pool used for the development k8s cluster is `k8sdev-pool-ec42-metadata` and the pool used by the production k8s cluster is `k8s-pool-ec42-metadata`.

### Mount the RBD Image

The RBD image can now be made available to the Linux command line.

First map the RBD image to a Linux device:

```
sudo rbd --id k8sdevrbd -p k8sdev-pool-ec42-metadata map csi-vol-60d4a0cd-8b7e-11ec-89be-96b0610b4778
sudo rbd showmapped
```

Make a temporary directory to mount the image to:

```
sudo mkdir /mnt/recovery-test
```

When the RBD image is mapped, note the Linux device name that it is mapped to and use in the following command:

```
sudo mount /dev/rbd0 /mnt/recovery-test
```

When mounting the RBD imaage make sure is not running and mounted on another host, or file system corruption will occur. For example, if the pod is still running, any data that it is writing to the PV may not appear on the Linux mounted filesystem.


### Copy data from the RBD image to a backup disk location or another RBD image

In this example, the pod's data is now available at `/mnt/recovery-test` and can be copied to a backup directory or another Linux mounted PV using Linux commands.


## Data Recovery For CephFS Based PVs

### Determine the pod's PVC

If the affected pod is still running, determine the PVC that it is using. The test example is using `busybox` and is in the namespace `metadig`:

```
$ kubectl describe deployment busybox -n metadig
Name:                   busybox
Namespace:              metadig
CreationTimestamp:      Fri, 11 Feb 2022 15:24:38 -0800
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=busybox
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=busybox
  Containers:
   busybox:
    Image:      docker.io/busybox:1.29
    Port:       <none>
    Host Port:  <none>
    Args:
      sh
      -c
      sleep 9999999999
    Environment:  <none>
    Mounts:
      /var/lib/www/html from myvol (rw)
  Volumes:
   myvol:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  cephfs-metadig-pvc
    ReadOnly:   false
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   busybox-77bdfd6c8d (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  16s   deployment-controller  Scaled up replica set busybox-77bdfd6c8d to 1
```

The listing shows that the PVC name is `cephfs-metadig-pvc `.

If the application is not running, the application manifest can be inspected for the PVC name. This is the application manifest used in this example:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: metadig
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
          - name: myvol
            mountPath: /var/lib/www/html
      volumes:
        - name: myvol
          persistentVolumeClaim:
            claimName: cephfs-metadig-pvc
            readOnly: false

```

### Determine the PV used by the PVC

Next, determine the PV that is being used by the PVC by listing all PVs currently running:

```
$ kubectl get pv -o wide
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS        CLAIM                                  STORAGECLASS   REASON   AGE     VOLUMEMODE
bookkeeper-pv                              50Gi       RWX            Retain           Bound         bookkeeper/bookkeeper-pvc                                      172d    Filesystem
cephfs-dataone-solr-pv                     100Gi      RWX            Retain           Bound         dataone-solr/cephfs-dataone-solr-pvc                           5h53m   Filesystem
cephfs-gnis-pv                             75Gi       RWX            Retain           Bound         gnis/cephfs-gnis-pvc                                           99d     Filesystem
cephfs-metadig-pv                          50Gi       RWX            Retain           Bound         metadig/cephfs-metadig-pvc                                     99d     Filesystem
cephfs-slinky-pv                           50Gi       RWX            Retain           Bound         slinky/cephfs-slinky-pvc                                       99d     Filesystem
gnis-pv                                    75Gi       RWX            Retain           Terminating   gnis/gnis-pvc                          manual                  158d    Filesystem
pvc-05119da3-50cd-43aa-aa42-b7b32c1ffed2   50Gi       RWO            Retain           Bound         polder/polder-pvc-01                   csi-rbd-sc              58d     Filesystem
pvc-55d4c915-2e26-4d76-b777-f0808ac1d01f   50Gi       RWO            Retain           Terminating   polder/polder-pvc-02                   csi-rbd-sc              58d     Filesystem
slinky-pv                                  75Gi       RWX            Retain           Released      slinky/slinky-pvc                      manual                  158d    Filesystem
```

This listing shows that the PV named `cephfs-metadig-pv` is being used by the PVC  `ceph-metadig-pvc` in the `metadig` namespace (see under the `CLAIM` column). 

Note that the CephFS subvolumes that some DataONE apps use are manually provisioned and are not deleted when the PV is deleted. A pod's data on these subvolumes will not be deleted when the PV is deleted.

### Locate the CephFS subvolume

Now that the PV name is known, the CephFS subvolume used by the PV can be identified.

First find the subvolue path using the PV name:

```
$ kubectl describe pv cephfs-metadig-pv
Name:            cephfs-metadig-pv
Labels:          <none>
Annotations:     pv.kubernetes.io/bound-by-controller: yes
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:
Status:          Bound
Claim:           metadig/cephfs-metadig-pvc
Reclaim Policy:  Retain
Access Modes:    RWX
VolumeMode:      Filesystem
Capacity:        50Gi
Node Affinity:   <none>
Message:
Source:
    Type:              CSI (a Container Storage Interface (CSI) volume source)
    Driver:            cephfs.csi.ceph.com
    FSType:
    VolumeHandle:      cephfs-metadig-pv
    ReadOnly:          false
    VolumeAttributes:      clusterID=8aa4d4a0-a209-11ea-baf5-ffc787bfc812
                           fsName=cephfs
                           rootPath=/volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856
                           staticVolume=true
Events:                <none>
```

The CephFS subvolume name is the 3rd component of the `rootPath`, which is shown in the listing as `k8sdevsubvol`.

### Mount the CephFS subvolume

The CephFS subvolue can now be made available to the Linux command line.

Make a directory to mount the image to, first ensuring that this subvolume has not previously been mounted:

```
sudo mkdir /mnt/k8sdevsubvol
```

Next, mount the subvolume, using the command:

```
sudo mount -t ceph 10.0.3.197:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856 \
   /mnt/k8sdevsubvol -o name=k8sdevsubvoluser,secretfile=/etc/ceph/k8sdevsubvoluser.secret

```

Note that a slightly different naming convention is used for the production k8s CephFS subvolumes, which do not include 'dev' in any names.

### Copy data from the CephFS filesystem 

Data can now be copied from the CephFS mounted filesystem to a backup disk location or another CephFS PV that has been made available in the same manner as the first one.

In this example, the pod's data is now available at `/mnt/k8sdevsubvol` and can be copied to a backup directory or another Linux mounted PV using Linux commands.


