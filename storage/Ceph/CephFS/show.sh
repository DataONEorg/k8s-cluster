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
sudo ceph -n client.k8ssubvoluser --keyring=/etc/ceph/ceph.client.k8ssubvoluser.keyring fs subvolume info cephfs k8ssubvol --group_name k8ssubvolgroup
