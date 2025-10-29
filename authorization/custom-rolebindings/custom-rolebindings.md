# Custom Roles and RoleBindings

> [!CAUTION]
> We need to practise the **principle of least privilege** when granting access to resources. Do not grant more permissions than are absolutely necessary for the application to function, and don't grant them more widely than necessary (e.g. to other accounts, and/or at cluster level).

Some products may require custom permissions to function correctly, in addition to those provided by the standard application-context.yaml definitions we apply by default when creating new contexts & associated service accounts.

These permissions should not be added to `application-context.yaml`, unless they are appropriate for all other contexts and clusters. Instead, add them to this directory as separate YAML files defining custom Roles and RoleBindings.

## Installation Notes

When adding new entries, make notes below, regarding any special steps needed during the installation process.

### QGNET Argo Workflows

1. As admin, create the context and apply the custom rolebindings:

    ```shell
    ## In DataONEorg/k8s-cluster/authorization:
    ./configure-k8s-service-account.sh qgnet prod

    kubectl apply ./custom-rolebindings/qgnet-argo.yaml
   ```

2. Install the CRDs for Argo Workflows (had trouble accessing directly from GH, so downloaded them first)

    ```shell
    ## In a temp directory:
    git clone git@github.com:argoproj/argo-workflows.git
    cd argo-workflows/manifests/base/crds
    kubectl create -k ./full
    ```
   (**Note**: Don't use `kubectl apply`, since that doesn't handle the large documentation sizes in the argo crd definitions, resulting in errors)
