
# Ceph CSI

Up to: [Storage provisioning](../storage.md)

The Ceph Container Storage Interface (CSI) driver (https://github.com/ceph/ceph-csi) for Ceph Rados Block Device (RBD) and Ceph File System (CephFS) can be used to provide Ceph storage to applications running on k8s. 

The Ceph CSI k8s driver can provision k8s persistent volumes (PVs) as RBD (RADOS Block Devices) images, but accessing Ceph storage in this way currently does not allow multiple k8s pods to access the same storage in RWX (read write many) mode. For this reason, Ceph CSI is used to provision PVs based on CephFS. 

# Installation ceph-csi Cephfs Plugin

Ceph CSI releases are available from github, for example: https://github.com/ceph/ceph-csi/releases/tag/v3.4.0. Releases can be installed by downloading the release from git hub and following the directions at https://github.com/ceph/ceph-csi/blob/devel/docs/deploy-cephfs.md.

Alternatively, releases can be installed via helm by following the directions using the helm installation instructions at https://github.com/ceph/ceph-csi/blob/devel/charts/ceph-csi-cephfs/README.md. This installation method is simplier than installation from a downloaded release.

First create the namespace that csi-ceph will execute in:
```
kubectl create namespace ceph-csi-cephfs
```

# Installation with Helm

First add the appropriate helm repository to read the release from:

```
helm repo add ceph-csi https://ceph.github.io/csi-charts
```

Command line options to helm supply most of the information that is needed for the installation. Two items that need to be manually created and installed are the `secret.yaml`, and `csi-config-map.yaml` files.

The `secret.yaml` file contains the ceph storage cluster login credentials needed for ceph-csi to mount CephFS subvolumes that are statically provisioned. These statically provisioned subvolumes have been created manually with the ceph utility. The `userId` and `userKey` values provide the needed authorization for this. Note that for dynamically provisioned (ceph-csi provisions them) CephFS volumes and subvolumes, the `adminId` and `adminKey` values are required. The values for these items can be found in the /etc/ceph directory of the k8s control nodes.

Once `secret.yaml` has been created, add it to k8s:
```
  kubectl create -f secret.yaml
```

Here is `secret.yaml`, with the credentials not filed in, for security considerations:

```
---
apiVersion: v1
kind: Secret
metadata:
  name: csi-cephfs-secret
  #namespace: ceph-csi-cephfs
  namespace: default
stringData:
  # Required for statically provisioned volumes
  userID: <plantext ID>
  userKey: <Ceph auth key corresponding to the ID above>

  # Required for dynamically provisioned volumes
  #adminID: <plaintext ID>
  #adminKey: <Ceph auth key corresponding to ID above>
```

The `csi-config-map.yaml` file contains the ceph cluster id and monitor node addresses. Due to a bug in helm that does not allow JSON to be specified in an argument, this config map must be manually maintained, instead of it's contents being specified on the command line with the `--set csiConfig=` argument. (See https://github.com/helm/helm/issues/1556, https://github.com/helm/helm/issues/5618)

Once this file has been created, it should be added to k8s:
```
kubectl create -f csi-config-map.yaml
```

Next, the ceph-csi-cephfs plugin is installed:

```
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

# Persistent Volume Provisioning

Each CephFS subvolume will correspond to a k8s persistent volume (PV). Because the ceph-csi cephfs plugin is being used, this PV can be mounted RWX, meaning that the PV can be mounted for write access by multiple k8s pods on multiple nodes.

Directions for manually creating the CephFS subvolumes are shown here https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/cephfs.md#commands-used-to-create-cephfs-subvolumes-on-the-dataone-ceph-cluter-ceph-15.

Once a ceph subvolume has been created, and the ceph-cis cephfs plugin has been started, it can be mounted as a k8s PV. For example, the file `cephfs-static-pv.yaml`:

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
      namespace: default
    volumeAttributes:
      # Required options from storageclass parameters need to be added in volumeAttributes
      "clusterID": <clusterId>
      #"fsName": "k8sdev"
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
mount -t ceph 10.0.3.197:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856 /mnt/k8sdevsubvol
```

# Persistent Volume Claim

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

# Using The PVC

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

To start this Deployment:

```
kubectl create -f busybox.yaml
```

Note that this Deployment is in the same namespace ("default") as the PVC.

# Uninstalling ceph-csi

First delete any PVCs and PVs that are using ceph. From our example:

```
kubectl delete -f busybox.yaml
kubectl delete -f cephfs-static-pvc.yaml
kubectl delete -f cephfs-static-pv.yaml
```

Next, stop ceph-csi and delete the manually created items:

```
helm uninstall "ceph-csi-cephfs" --namespace "ceph-csi-cephfs"
kubectl delete namespace ceph-csi-cephfs
kubectl delete -f csi-ceph-config.yaml
kubectl delete -f secret.yaml
helm status "ceph-csi-cephfs"
```

# Troubleshooting

If it ever occurs that a PV can't be unmounted after stoping ceph-csi, follow the directions from https://github.com/kubernetes/kubernetes/issues/77258
if the pv name is cephfs-static-pv, for example:

```
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pvc cephfs-static-pvc -p '{"metadata":{"finalizers":null}}'
- kubectl patch pv cephfs-static-pv -p '{"metadata":{"finalizers":null}}'
- kubectl patch pod pod/busybox-68df577cd8-s9x8w -p '{"metadata":{"finalizers":null}}'
```


