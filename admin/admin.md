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
```
kubectl get nodes
kubectl drain <node name>
<reboot the node>
kubectl uncordon <node name>
```

#### Controllers


## Add/Removing Hosts

## Upgrading K8s
