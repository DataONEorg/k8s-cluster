#!/bin/bash

kubectl get sc
kubectl get pvc -n ceph-csi-rbd
kubectl describe sc csi-rbd-sc -n ceph-csi-rbd
kubectl describe pvc ceph-rbd-pvc -n ceph-csi-rbd

