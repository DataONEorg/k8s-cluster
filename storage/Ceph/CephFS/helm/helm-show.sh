
helm status "ceph-csi-cephfs" \
  --namespace "ceph-csi-cephfs"

kubectl describe cm ceph-csi-config -n ceph-csi-cephfs
