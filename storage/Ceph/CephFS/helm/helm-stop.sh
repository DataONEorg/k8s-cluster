helm uninstall "ceph-csi-cephfs" \
  --namespace "ceph-csi-cephfs" \

kubectl delete namespace ceph-csi-cephfs
#helm status "ceph-csi-cephfs" --namespace "ceph-csi-cephfs"
