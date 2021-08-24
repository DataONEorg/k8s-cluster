# Control Plane Configuration

Up to: [DataONE Cluster Overview](../cluster-overview.md)

The Kubernetes control plane is a replicated set of services that controls all cluster services, and sits behind a load balancer to provide fault tolerance. It is configured as a "Stacked" typology, with each control plane node also hosting one of the replicas of the `etcd` configuration service.

### Control plane high availability

Creating a fault tolerant cluster requires that redundant control planes are available should one fail. The [recommended minimal configuration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/) is to host three control planes using a stacked `etcd` topology:

![Stacked HA cluster](https://d33wubrfki0l68.cloudfront.net/d1411cded83856552f37911eb4522d9887ca4e83/b94b2/images/kubeadm/kubeadm-ha-topology-stacked-etcd.svg)

This is the approach that we have taken for the DataONE cluster. One of the three control-plane nodes can be taken offline to be upgraded, maintained, or migrated to a new host, and the remaining two can still achieve a quorum. See [control plane configuration](control-plane/control-plane.md) for details.

## Control Plane Configuration

Describe control-plane configuration...

## Load Balancer

Decribe Load Balancer configuration...

## etcd service

Decribe etcd service configuration...

## Ingress Controller

The DataONE k8s Cluster uses the [NGINX ingress controller](https://github.com/kubernetes/ingress-nginx) (NIC) to route traffic to k8s services from clients outside of the cluster. This is the community maintained version of the NGINX ingress controller, that is separate from the [NGINX INC. ingress controller](https://github.com/nginxinc/kubernetes-ingress).

### Installation:

The NIC is installed using the instructions for a [bare-metal installation](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal). The default is to install using the pre-created Helm charts or to use the filled out manifest file (aka deployment file). After the installation completes, then [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#the-ingress-resource) resources can be added. If the ingresses are configured correctly, the NIC will detect and use them, thereby enabling routing to the DataONE k8s services.

The DataONE NIC installation currently uses a modified version of the [deployment manifest file](https://github.com/kubernetes/ingress-nginx/blob/dev-v1/deploy/static/provider/baremetal/deploy.yaml). The modifications to the default deployment file are described in the next section. Note that the deployment file is an aggregation of all manifest files needed to configure resources and start services for the NIC.

### Configuration
#### Ingress Class
The NIC requires that a k8s [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class) is defined. This associates the NIC with one class of ingress. Using this approach, it is therefore
possible to have multiple ingress controllers of different types (i.e. HAproxy ingress controller, NGINX ingress controller...), running on the same cluster.

When the NIC is started, it is told which class of ingress to use by specifying the command line argument `--ingress-class=<namespace><ingress class name>`, for example ` --ingress-class=nginx`. After staring, the NIC will inspect ingress objects from all namespaces and use the ones that have a class name that matches the one it is using. (Attempting to have multiple classes defined for the DataONE NIC has not been attempted.)

The default ingress class specified in the deploy.yaml file includes the namespace and class name:

```
            - --ingress-class=$(POD_NAMESPACE)/nginx
```

This has been modified to not specify the namespace, so that the NIC will search in all namespaces for ingress resources.

```
            - --ingress-class=nginx 
```

Note that an *IngressClass* defintion is associated with a particular ingress controller with the 'spec.controller' value, for example from `controller-ingressclass.yaml` section of `deploy.yaml`:

```
spec:
  controller: "k8s.io/ingress-nginx"
```

The value `k8s.io/ingress-nginx` is hard-coded in the NIC software and is unique the the NIC.

Therefore, both of thse steps are required:

- specify the ingress controller to use in the *Ingressclass* defintion
- specify the ingress class to use from the ingress controller deployment manifest.

#### Ingress
An [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#the-ingress-resource) resource specifies the routing from the ingress controller NodePort to a k8s service. See [ingress-metadig](TODO: provide link) for an example.

These ingress resources are defined in the same namespace as the services that they route to, so for example, the `metadig` ingress is defined in the `metadig` namespace, where the `metadig-controller` service that it routes to is located.

Note that the NIC will continue to scan for ingress objects and add them as required. 

A separate ingress resource is defined for each DataONE service, for example the `gnis` service in the `gnis` namespace, with a separate ingress resource, but using the 'nginx' ingress class.

#### SSL Termination

For DataONE k8s, Let's Encrypt (LE) is used for Transport Layer Security encryption. The NIC provides SSL termination. The LE certificate is made available to the NIC by inserting it into a k8s secret. The secret is specified in an ingress that is read by the NIC, for example in `ingress-metadig.yaml`:

```
spec:
  ingressClassName: nginx
  tls:
  - hosts:
      - api.test.dataone.org
    secretName: <secret-name>
```

The LE certificate and secret are maintained by DataONE admin scripts.
Since the ingress resources exist in each service namespace, this secret can be repeated in each namespace, but it appears that the NIC only requires it to be in one namespace. This may be a result of the NIC appending together (in memory) all ingresses that it detects.

#### NodePort

The DataONE NIC is configured to use a k8s NodePort service, as described in [Bare-metal considerations](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#over-a-nodeport-service). 
This configuration provides external access to DataONE services via a URL that specified the port that is made available via the NodePort service.


#### Deploying The NGINX Ingress Controller

The manifest files in the *nginx-ingress-controller* directory have been extracted from the deploy.yaml. The webhook capabilities of the NGINX ingress controller are not being used, so those manifests are not included, for example *controller-service-webhook.yaml* is not used.

The following commands are used to configure resources and RBAC, and only need to be invoked once, or when upgrades or modifications are made:

```
kubectl create -f namespace.yaml
kubectl create -f clusterrolebinding.yaml
kubectl create -f clusterrole.yaml
kubectl create -f controller-configmap.yaml
kubectl create -f controller-rolebinding.yaml
kubectl create -f controller-role.yaml
kubectl create -f controller-serviceaccount.yaml
kubectl create -f controller-ingressclass.yaml
```

These next commands start the NGINX Ingress Controller pod and service

```
kubectl create -f controller-deployment.yaml
kubectl create -f controller-service.yaml
```

Next, an ingress resource is created for each service that the ingress controller will provide routing for:

```
kubectl create -f ingress-metadig.yaml
```

Note that `ingress-metadig.yaml` is part of the *MetaDIG* service, but is included here for illustration.
