kubectl get pv
echo ""
kubectl get pvc -n metadig

echo "----------"
echo "cephfs-static-pv:"
kubectl describe pv cephfs-static-pv
echo "----------"
echo "cephfs-static-pvc:"
kubectl describe pvc cephfs-static-pvc -n metadig

echo "----------"
echo "Ceph status:"
sudo ceph -n client.k8sdevsubvoluser --keyring=/etc/ceph/ceph.client.k8sdevsubvoluser.keyring fs subvolume info cephfs k8sdevsubvol --group_name k8sdevsubvolgroup
