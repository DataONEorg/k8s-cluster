# K8s Cluster Administration

Up to: [DataONE Cluster Overview](../cluster-overview.md)


## Rebooting

#### Nodes
To reboot a node, first drain the node, reboot, then add the node back:
```bash
$ ssh metadig@k8s-ctrl-1.dataone.org
metadig@docker-ucsb-4:~$ kubectl config use-context prod-k8s   # Update ~metadig/.kube/config if this fails

metadig@docker-ucsb-4:~$ kubectl get nodes
NAME            STATUS   ROLES                  AGE     VERSION
docker-ucsb-4   Ready    control-plane,master   2y97d   v1.23.4
k8s-node-123    Ready    <none>                 362d    v1.23.4
k8s-node-2      Ready    <none>                 2y96d   v1.23.4
k8s-node-3      Ready    <none>                 2y96d   v1.23.4

metadig@docker-ucsb-4:~$ kubectl drain k8s-node-123 --ignore-daemonsets --delete-emptydir-data --force
```

Reboot the drained node:
```bash
$ ssh k8s-node-123.dataone.org
outin@k8s-node-123:~$ sudo reboot
```

Add the node back:
```bash
kubectl uncordon k8s-node-123
```

#### Controllers
No steps are necessary before rebooting the controller (currently k8s-ctrl-1).


## Adding a Node

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
k8s-ctrl$ kubectl drain k8s-node-new --ignore-daemonsets --delete-emptydir-data --force
k8s-ctrl$ kubectl cordon k8s-node-new
```


## Deleting a Node
```
k8s-ctrl$ kubectl drain k8s-node-123 --ignore-daemonsets --delete-emptydir-data --force
k8s-ctrl$ kubectl delete node k8s-node-123

# Optional, run on the deleted node to reset K8s config
k8s-node-123$ kubeadm reset
```



## Assigning Pods to Nodes
Different nodes may have different resources and you may restrict a pod to run on particular node(s). In order to do so, you may first label a node.

### Labeling Nodes
The following command gives a node named `k8s-dev-node-4` a label `nceas/nodegroup` with the value `fast`:
```
kubectl label nodes k8s-dev-node-4 nceas/nodegroup=fast
```

### Setting NodeAffinity
The bellow section of code may be added to the Values.yaml on the top level in your application. It will constrain the pod(s) to run on the nodes having the label `nceas/nodegroup` with the value `fast`. If the selector cannot select a node or nodes, the pod cannot be generated.
```
affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nceas/nodegroup
            operator: In
            values:
            - fast
```


## Renewing Certs

1. Check cert expiration:
```
kubeadm certs check-expiration
```

2. Renew the certs:
```
kubeadm certs renew all
kubeadm certs check-expiration
```

3. Reboot the controller
```
sudo reboot
```

4. Update the config-dev/config-prod gpg file
    - Copy the keys `cluster/certificate-authority-data` and user info for the `dev-k8s` or `prod-k8s` users (`user/client-certificate-data` and `user/client-key-data` from `/etc/kubernetes/admin.conf` into the appropriate `config-dev`/`config-prod` file
        - Note that the admin.conf uses a different username than we use in our client files (we use `dev-k8s` and `prod-k8s` as the context usernames)
        - Be sure to leave the other contexts (including user accounts, namespaces, etc) in place, such as `dev-slinky`, `dev-metadig`, etc.
    - GPG encypt the modified `config-dev`/`config-prod` file
    - Upload to https://github.nceas.ucsb.edu/NCEAS/security/tree/main/k8s
