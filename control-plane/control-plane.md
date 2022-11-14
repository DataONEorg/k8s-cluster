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

The NIC is installed using the instructions for a [bare-metal installation](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal). 
The NIC can be installed using helm v3+, using the following command:

```
helm upgrade --install ingress-nginx ingress-nginx \
  --version=4.0.6 \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.defaultBackend.enabled=true \
  --set controller.ingressClassResource.default=true \
  --set controller.ingressClassResource.name=nginx \
  --set controller.service.externalIPs={128.111.85.192} \
  --set controller.service.type=NodePort
```

The current version of the NIC can be determined by using the command:

```
$ helm search repo ingress-nginx
NAME                        CHART VERSION APP VERSION DESCRIPTION
ingress-nginx/ingress-nginx 4.0.8         1.0.5       Ingress controller for Kubernetes using NGINX a...
```
Note that the version of the most recent `released` chart should be specified, so that the development `canary` version is not installed, which is the default.

Note that this NIC configuration uses the k8s `externalIP` mechanism to make the k8s `ingress-nginx-controller` service accessible to clients that are external to the k8s network. The IP selected is for one of the k8s nodes that is accessible from any client address. The above example is for the DataONE production k8s cluster and uses the IP address of the control node `k8s-ctrl-1.dataone.org`.

Note that some clients may still be referrencing ports `30080` or `30443` instead of the standard `80` and `443`. The NIC helm chart does not support configuring these ports via the helm command line, so the NIC service definition has to be manually configured to add these extra ports. To do this:
<ol>
  <li>Install NGINX Ingress Controller with the command shown above</li>
  <li>Manually create the NIC service defintion file using helm</li>
  Helm can generate manifest files that are equivalent to the installation performed with the `upgrade` command. Use the following command to generate the composite YAML file:
  
```
  helm template ingress-nginx ingress-nginx \
  --dry-run --debug \
  --version=4.0.6 \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.defaultBackend.enabled=true \
  --set controller.ingressClassResource.default=true \
  --set controller.ingressClassResource.name=nginx \
  --set controller.service.type=NodePort \
  --set controller.service.externalIPs={128.111.85.190} > nginx-deploy.yaml
```
  <li>Add the required ports to the definition</li>
  Extract the section for `controller-service.yaml` from the file `nginx-deploy.yaml` with a text editor, to the file `controller-service-additional-ports.yaml`, and add the following lines to the `spec.ports` section, under the `-name: https` item:
  
  ```
    - name: http2
      port: 30080
      protocol: TCP
      targetPort: http
      appProtocol: http
    - name: https2
      port: 30443
      protocol: TCP
      targetPort: https
      appProtocol: https
  ```
      
  <li>Update the definition/li>
  The NGINX Ingress Controller is already running from the `helm` update command above, so now modify the NIC service to add the additional ports with the command:
```
kubectl apply -f controller-service-additional-ports.yaml
```
<li>Check that the ports are available</li>
Use `kubectl` to check that all desired ports are available.

```
$ kubectl get service ingress-nginx-controller -n ingress-nginx
NAME                       TYPE       CLUSTER-IP      EXTERNAL-IP      PORT(S)                                                      AGE
ingress-nginx-controller   NodePort   10.102.44.189   128.111.85.192   80:31590/TCP,443:30443/TCP,30080:32036/TCP,30443:31257/TCP   19d
```
</ol>

Note that once the additional ports `30080` and `30443` are no longer required by client programs, these additional steps will no longer be required after the `helm` upgrade command.

### Configuration
#### Ingress Class
The NIC requires that a k8s [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class) is defined. This associates the NIC with one class of ingress. Using this approach, it is therefore
possible to have multiple ingress controllers of different types (i.e. HAproxy ingress controller, NGINX ingress controller...), running on the same cluster.

An *IngressClass* resource is automatically created by the helm installation, so does not need to be manually created or configured.

When the NIC is started it will search all namespaces for `Ingress` objects with an ingress class that matches the ingress class name `nginx`. DataONE is currently only using a single NIC, but it is possible to have multiple NICs for a k8s cluster, with each one managing its own class.

#### Ingress
An [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#the-ingress-resource) resource specifies the routing from the ingress controller NodePort to a k8s service. See [ingress-metadig](TODO: provide link) for an example. Each k8s application that runs on the k8s cluster must create an `Ingress` resource in order to provide routing. In addition, the `cert-manager` facility interacts with the `Ingress` resource to provide a Let's Encrypt certificate for TLS termination for the service (this is describe in the `Authentication` section).

These ingress resources are created in the same namespace as the services that they route to, so for example, the `metadig` ingress is defined in the `metadig` namespace, where the `metadig-controller` service that it routes to is located.

Note that the NIC will continue to scan for ingress objects that match the ingress class `nginx` and will setup routing when ingress resources are added. 

A separate ingress resource is defined for each DataONE service, for example the `gnis` service in the `gnis` namespace, with a separate ingress resource, but using the 'nginx' ingress class.

#### Exposing TCP Services
Ingress does not support TCP services. For this reason the Ingress controller uses the flag `--tcp-services-configmap` to point to an existing config map which indicates the services. Here are the details:
<ol>
  <li>Upload a config map:</li>
  
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
data:
  5672: "d1index/d1index-rabbitmq:5672"
  8983: "d1index/d1index-solr:8983"
```
This example shows how to expose the service `d1index-rabbitmq` running in the namespace `d1index` in the port `5672` using the port `5672`; another service `d1index-solr` in the namespace `d1index` in the port `8983` using the port `8983`. You may use the command of `kubectl apply` to upload the config map.

  <li>Pass the configure map configuration to the controller by editing the deployment of the ingress-nginx-controller:</li>
  
```
kubectl edit deployments -n ingress-nginx ingress-nginx-controller
```
Add the line under spec.template.spec.containers.args and save it:
  
```
- --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
```
The modification of the deployment will automatically trigger the reloading of the ingress-nginx-controller pods.

  <li>Add the new node ports:</li>
In the file `controller-service-additional-ports.yaml` mentioned in the above section, add thoses lines:
  
```
- name: rabbitmq-tcp
  port: 5672
  protocol: TCP
  targetPort: 5672
- name: solr-https
  port: 8983
  protocol: TCP
  targetPort: 8983
  appProtocol: https
```
Then apply the file by this command:
  
```
kubectl apply -f controller-service-additional-ports.yaml
```
Check that those ports are available:
  
```
kubectl get service ingress-nginx-controller -n ingress-nginx
NAME                       TYPE       CLUSTER-IP     EXTERNAL-IP      PORT(S)                                                                                    AGE
  ingress-nginx-controller   NodePort   10.106.98.34   128.111.85.190     80:32403/TCP,443:30214/TCP,30080:30343/TCP,30443:32163/TCP,5672:31122/TCP,8983:32480/TCP   278d
```
</ol>
