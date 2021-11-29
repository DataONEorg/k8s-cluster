
helm status "ceph-csi-rbd" --namespace "ceph-csi-rbd"

kubectl describe cm ceph-csi-config -n ceph-csi-cephfs
