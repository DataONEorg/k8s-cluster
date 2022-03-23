#!/bin/bash
sudo mount -t ceph 10.0.3.197:6789,10.0.3.207:6789,10.0.3.214:6789,10.0.3.222:6789,10.0.3.223:6789:/volumes/k8ssubvolgroup/k8ssubvol/af348873-2be8-4a99-b1c1-ed2c80fe098b \
   /mnt/k8ssubvol -o name=k8ssubvoluser,secretfile=/etc/ceph/k8ssubvoluser.secret


