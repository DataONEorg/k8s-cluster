Example command used to upgrade from 3.7.2 to 3.8.1:

```
helm upgrade --namespace ceph-csi-rbd ceph-csi-rbd ceph-csi/ceph-csi-rbd \
  --version 3.8.1 \
  --set rbac.create=true \
  --set serviceAccounts.nodeplugin.create=true \
  --set serviceAccounts.provisioner.create=true \
  --set configMapName=ceph-csi-config \
  --set externallyManagedConfigmap=true \
  --set nodeplugin.name=csi-cephrbdplugin \
  --set logLevel=5 \
  --set nodeplugin.registrar.image.tag="v2.6.2" \
  --set nodeplugin.plugin.image.tag="v3.8.1" \
  --set secret.create=false \
  --set secret.name=csi-cephrbd-secret \
  --set storageClass.create=false \
  --dry-run --debug
```


Version upgrades are recommended to be done sequentially per https://github.com/ceph/ceph-csi/blob/devel/docs/ceph-csi-upgrade.md

The nodeplugin.registrar versions can be found at https://github.com/kubernetes-csi/node-driver-registrar
