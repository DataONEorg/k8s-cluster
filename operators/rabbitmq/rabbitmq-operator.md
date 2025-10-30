# RabbitMQ Cluster Operator

## RabbitMQ Cluster Operator Defaults

The operator was installed without overriding any of the [default environment variables](https://www.rabbitmq.com/kubernetes/operator/configure-operator-defaults#parameters). Most notably, this means that the Operator: 
- watches all namespaces for RabbitMQCluster resources (`OPERATOR_SCOPE_NAMESPACE`).
- uses the latest RabbitMQ container image available at time of release for new Pods (`DEFAULT_RABBITMQ_IMAGE`).
- does not control image version upgrades. The user is responsible for updating RabbitmqCluster image (`CONTROL_RABBITMQ_IMAGE`).


### The `kubectl rabbitmq` plugin

The `kubectl rabbitmq` plugin provides commands for managing RabbitMQ clusters; install it using [the Krew plugin manager for kubectl](https://krew.sigs.k8s.io/docs/user-guide/setup/install/krew):

```shell
kubectl krew install rabbitmq
```

`kubectl rabbitmq help` lists all commands, including the following useful ones:

```shell
## List all RabbitMQ clusters
kubectl rabbitmq [-n NAMESPACE | -A] list
    
## Print default-user secrets for an instance
kubectl rabbitmq [-n NAMESPACE] secrets INSTANCE

## Launch Management UI in a browser for an instance
## Automatically starts port-forwarding
## Need credentials from 'kubectl rabbitmq secrets' command
kubectl rabbitmq [-n NAMESPACE] manage INSTANCE

## Set log level to 'debug' on all nodes
kubectl rabbitmq [-n NAMESPACE] debug INSTANCE

## Tail logs from all nodes
## NOTES: 
##   - 'tail' subcommand requires the 'tail' plugin; install with 'kubectl krew install tail'
##   - Must explicitly define the namespace to use tail, otherwise results in RBAC errors
kubectl rabbitmq -n NAMESPACE tail INSTANCE

## Run a performance test job against an instance
kubectl rabbitmq [-n NAMESPACE] perf-test INSTANCE
```

## Creating a RabbitMQ Instance

Refer to: [Using the RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/using-operator.html), for details on creating RabbitMQ clusters using the Operator, including configurable properties and their defaults.

You can use a super-simple definition like this:

```yaml
## $ cat rabbitmq.yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: myreleasermq
```

...to deploy an instance:

```shell  
$ kubectl apply -f rabbitmq.yaml
rabbitmqcluster.rabbitmq.com/hello-world created
```

This creates a `StatefulSet` with a single RabbitMQ Pod named `myreleasermq-server-0`, using all default settings. It also creates a 10Gi `PVC` using the default storage class, and a `ClusterIP` Service named `myreleasermq`, to expose ports `amqp:5672, management:15672`, and `prometheus:15692` within the cluster. The default `resources` assigned are:

```yaml
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 2
    memory: 2Gi
```
The credentials are stored in a Secret named `myreleasermq-default-user`, and can easily be retrieved using the `kubectl rabbitmq` plugin:

```shell
$ kubectl rabbitmq secrets myreleasermq
username: default_user__xHBwZjei3Pp2kYo8LJ
password: y2rtDOP7xISwt_kPJ_dEbiBQeB-nsc1w
```
...allowing you to log into the management console web UI, launched using:
```shell
$ kubectl rabbitmq manage myreleasermq
```
...and then you can run a performance test against the instance using:
```shell
$ kubectl rabbitmq perf-test myreleasermq
```
...and see it in action, in the management console web UI.


## RabbitMQ Cluster Operator Installation/Upgrade

> [!CAUTION]
> In some cases, UPGRADING the version of the RabbitMQ Cluster Operator will cause the Pods of `RabbitmqClusters` to be RESTARTED. See [Upgrading the RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/upgrade-operator) for more details. Therefore, Before upgrading, check the [RabbitMQ Cluster Operator releases page](https://github.com/rabbitmq/cluster-operator/releases/).

The RabbitMQ Cluster Operator is only installed once on a Kubernetes cluster, and can be used by all applications to deploy RabbitMQ. To install the latest version of the Operator, run the following command (as admin):

```shell

$ kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

namespace/rabbitmq-system created
customresourcedefinition.apiextensions.k8s.io/rabbitmqclusters.rabbitmq.com created
serviceaccount/rabbitmq-cluster-operator created
role.rbac.authorization.k8s.io/rabbitmq-cluster-leader-election-role created
clusterrole.rbac.authorization.k8s.io/rabbitmq-cluster-operator-role created
clusterrole.rbac.authorization.k8s.io/rabbitmq-cluster-service-binding-role created
rolebinding.rbac.authorization.k8s.io/rabbitmq-cluster-leader-election-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/rabbitmq-cluster-operator-rolebinding created
deployment.apps/rabbitmq-cluster-operator created
```

(You can also use [the kubectl rabbitmq plugin](#the-kubectl-rabbitmq-plugin) to install the RabbitMQ Cluster Operator plugin -- `kubectl rabbitmq install-cluster-operator` -- instead of applying the yaml file above.)

As seen above, this creates the necessary k8s resources, including the `rabbitmq-system` namespace, which contains the RabbitMQ Cluster Operator deployment:

```shell
$ kubectl get all -n rabbitmq-system
NAME                                            READY   STATUS    RESTARTS   AGE
pod/rabbitmq-cluster-operator-6bff64df8-hrkgw   1/1     Running   0          14h

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rabbitmq-cluster-operator   1/1     1            1           14h

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/rabbitmq-cluster-operator-6bff64df8   1         1         1       14h
```

It also creates some rbac roles (needed to create, update and delete RabbitMQ Clusters), and the custom resource `rabbitmqclusters.rabbitmq.com`, which defines the API for creation of RabbitMQ Clusters:

```shell
$ kubectl get customresourcedefinitions.apiextensions.k8s.io | grep rabbit
rabbitmqclusters.rabbitmq.com                         2025-10-30T00:44:50Z
```
