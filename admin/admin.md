# K8s Cluster Administration

Up to: [DataONE Cluster Overview](../cluster-overview.md)


## Rebooting

### Nodes
To reboot a node, first drain the node, reboot, then add the node back:
```
kubectl get nodes
kubectl drain <node name>
<reboot the node>
kubectl uncordon <node name>
```

### Controllers


## Add/Removing Hosts

## Upgrading K8s
