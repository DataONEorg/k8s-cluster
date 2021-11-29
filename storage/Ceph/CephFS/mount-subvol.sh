#!/bin/bash
#ceph.client.k8s.keyring  ceph.client.k8srbd.keyring  ceph.client.k8ssubvoluser.keyring  ceph.conf  k8s.secret  k8ssubvoluser.secret  rbdmap

sudo mount -t ceph 10.0.3.197:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8sdevsubvolgroup/k8sdevsubvol/4b7cd044-4055-49c5-97b4-d1240d276856 \
   /mnt/k8sdevsubvol -o name=k8sdevsubvoluser,secretfile=/etc/ceph/k8sdevsubvoluser.secret


