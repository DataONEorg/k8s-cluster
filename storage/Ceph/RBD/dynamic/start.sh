kubectl create namespace ceph-csi-rbd
kubectl apply -f csi-rbd-sc.yaml
kubectl apply -f ceph-rbd-pvc.yaml
