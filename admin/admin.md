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




## Add/Removing Hosts

## Upgrading K8s
