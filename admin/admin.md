# K8s Cluster Administration

Up to: [DataONE Cluster Overview](../cluster-overview.md)


## Rebooting

### Dev Cluster
Post downtime notices with >1 hour notice in NCEAS#devteam and DataONE#dev-general Slack channels.

The k8s-dev cluster currently has a single controller and node, and no place to drain to. The reboot process is:
1. Reboot k8s-dev-node-1
2. Reboot k8s-dev-ctrl-1

### Prod Cluster
#### Nodes
To reboot a node, first drain the node, reboot, then add the node back:
```bash
$ ssh metadig@k8s-ctrl-1.dataone.org
metadig@docker-ucsb-4:~$ kubectl config use-context prod-k8s   # Update ~metadig/.kube/config if this fails

metadig@docker-ucsb-4:~$ kubectl get nodes
NAME            STATUS   ROLES                  AGE     VERSION
docker-ucsb-4   Ready    control-plane,master   2y97d   v1.23.4
docker-ucsb-5   Ready    <none>                 362d    v1.23.4
docker-ucsb-6   Ready    <none>                 2y96d   v1.23.4
docker-ucsb-7   Ready    <none>                 2y96d   v1.23.4

metadig@docker-ucsb-4:~$ kubectl drain docker-ucsb-5 --ignore-daemonsets --delete-emptydir-data --force
```

Reboot the drained node:
```bash
$ ssh k8s-node-1.dataone.org
outin@docker-ucsb-5:~$ sudo reboot
```

Add the node back:
```bash
kubectl uncordon docker-ucsb-5
```

#### Controllers
No steps are necessary before rebooting the controller (currently k8s-ctrl-1).


## Adding a node

All commands are run on the new K8s node unless specified.

- Create a new VM using the [NCEAS Server Setup Docs]( https://github.nceas.ucsb.edu/NCEAS/Computing/blob/master/server_setup.md)

- Disable any swap files or partitions
```
sudo swapoff -a
sudo vim /etc/fstab
```

- Install the K8s deb repo from https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/ :
```
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

- Install K8s (the same version as on the controllers) and dependencies:
```
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common docker.io kubeadm=1.23.4-00 kubectl=1.23.4-00 kubelet=1.23.4-00
sudo apt-mark hold kubeadm kubelet kubectl
```

- Print the join command from the controller:
```
k8s-ctrl$ sudo kubeadm token create --print-join-command
```

- Paste and run the join command on the new node:
```
kubeadm join ...
```

- Verify that the new node has joined successfully from the controller:
```
k8s-ctrl$ kubectl get nodes -o wide
k8s-ctrl$ kubectl get pods -A -o wide
```

- Remove the new node if something went wrong
```
k8s-ctrl$ kubeadm drain k8s-node-new --ignore-daemonsets --delete-emptydir-data --force
k8s-ctrl$ kubeadm cordon k8s-node-new
```



