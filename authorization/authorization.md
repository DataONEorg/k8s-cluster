# Application Authorization

Up to: [DataONE Cluster Overview](../cluster-overview.md)

An application needs to be authorized to run on the DataONE Kubernetes (k8s) cluster.

Authorization is based on k8s `serviceaccounts`.

A few k8s configuration steps are required before an application can be installed
and run on the DataONE k8s cluster. The DataONE *slinky* application will be used as an
example of this setup.

The *kubectl* program is used to perform these configuration steps. The *kubectl* program can
operate in either a privileged admin mode, or in a restricted access mode. The k8s documentation
refers to these different modes as configuration *contexts*.

Operations that involve creating new resources, such as k8s namespaces, and accessing
global resources (available to more than one namespace) require an admin context.

The authorization approach that will be used for DataONE applications is to create a unique
k8s authorization configuration *context* for each application that will limit all interactions with
k8s to a single namespace that is used by only that application. (Note that multiple applications
could use the same namespace if desired, as the authorization context could be used by multiple
applications.)

## Create The kubectl Configuration File

A k8s *serviceAccount* is used as the subject that is authenticated when kubectl commands are
performed by a non-admin user.

The authorization information needed to authorization kubectl requests as the serviceAccount
subject is kept in a kubectl *configuration*
file that is created by the k8s admin user for each application. The script
`configure-k8s-service-account.sh` can be used to create the namespace, serviceAccount, and kubectl
configuration file for an application. The syntax is:

```shell
$ configure-k8s-service-account application-name cluster-prefix
```

where `application-name` is the intended namespace of the application, and `cluster-prefix` is
either `dev` for the `dev-k8s` cluster or `prod` for the `prod-k8s` cluster.
For example, to create the 'slinky' context, the admin user is used to invoke this script as:

```shell
    configure-k8s-service-account.sh slinky dev
```
This script will add the new context in two places:

1. It will be merged with the existing contents of the `~/.kube/config-dev` file. This new version
   of `config-dev` should be gpg-encrypted and pushed to git.
2. It will also be saved in a `<application-name>-dev.config` file, which contains only the details
   for that particular context (e.g. `slinky-dev.config`). This file is typically not pushed to git,
   but may be useful for sharing with outside developers who need access only to that context.

## Grant Additional Privileges To The serviceAccount

A serviceAccount is initially created with a default set of privileges granted as configured in the
template application-context.yaml file.

A k8s `role` and `rolebinding` are created to grant access to the serviceAccount to perform any
actions on the namespace created for the application. No actions on any other resource outside
the designated namespace are granted. To add additional privileges, you can update the `Role` and
`RoleBinding` resources for the service account, adding additional roles as needed, and updating it
with `kubectl apply`.

Note that the defaults will be applied in the initial creation of the `serviceaccount`, so this step
will usually not be needed.

## `clusterrole` and `clusterrolebinding`

> **Note**: Use this ONLY if you are sure that the application needs access to cluster-level
> resources. This is not recommended for most applications: it is a security risk and/or it may tie
> us too closely to the k8s model.

If an application needs to access resources at the cluster level, you can create a `ClusterRole` and
`ClusterRoleBinding` for the service account. The creation and application of these resources is
similar to those for `Role` `RoleBinding`, above. However, copies of the yaml for each should be
saved in the [custom-rolebindings](./custom-rolebindings) directory.

## Client Setup

From the user's perspective, the following initial setup is required upon receiving a copy of the kubectl configuration file:

1. Decrypt the file(s), which should have arrived in gpg-encrypted form.
2. Create a `~/.kube/` directory, move the file(s) into it, and `chmod 600` them, since they contain sensitive information.
3. Set up a KUBECONFIG environment variable that contains the path(s) to any of these files in `~/.kube/`, by adding something like this to your `~/.zshrc` (or  `~/.zshenv`) file. For example:
   ```shell
   # (substitute your own filenames)
   export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/config-prod:$HOME/.kube/config-dev"
   ```


## References

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
