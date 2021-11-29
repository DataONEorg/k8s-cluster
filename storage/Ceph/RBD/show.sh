#!/bin/bash

kubectl describe pv ceph-rbd-static-pv
echo "-----"
kubectl describe pvc ceph-rbd-static-pvc -n ceph-csi-rbd
echo "-----"
kubectl get deployment busybox -n ceph-csi-rbd

