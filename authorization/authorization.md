# Application Authorization

Up to: [DataONE Cluster Overview](../cluster-overview.md)

An application needs to be authorized to run on on the DataONE Kubernetes (k8s) cluseter. 

Authorization is based on k8s serviceaccounts.

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
k8s to a single namespace that is used by only that application. (Note that multiple applications could use the same
namespace if desired, as the authorization context could be used by multiple applications.)

## Create The kubectl Configuration File

A k8s *serviceAccount* is used as the subject that is authenticated when kubectl commands are
performed by a non-admin user. 

The authorization information needed to authorization kubectl requests as the serviceAccount
subject is kept in a kubectl *configuration*
file that is created by the k8s admin user for each application. The script *configure-k8s-service-account.sh*
can be used to create the namespace, serviceAccount, and kubectl configuration file for an application. 
The syntax is *configure-k8s-service-account application-name*

For example, to create the the 'slinky' context, the admin user is used to invoke this script as:
::

    configure-k8s-service-account.sh slinky 

This script will add the new context to the ~/.kube/config file.

## Grant Privileges To The serviceAccount

A serviceAccount is initially created without any privileges granted. 

A k8s role and rolebinding are created to grant access to the serviceAccount to perform any
actions on the namespace created for the application. No actions on any other resource outside
the designated namespace are granted. First edit the manifest file 'application-access.yaml',
changing the *name:* and *namespace:* properties to the desired value (e.g. 'slinky), then grant the privileges
using the k8s admin context:
::

    kubectl create -f application-access.yaml

## References
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
