# Limited Access

Limited access can be granted by giving someone access to a special, shared `ServiceAccount` that has the appropriate `ClusterRole` permissions assigned via a `RoleBinding` in the target namespace. See the [Pre-Requisites section](#pre-requisites) for details on initial setup of the `ServiceAccount` and `ClusterRole` for each type of access

For example, to give read-only access to logs in the `arctic` namespace (assuming the `ServiceAccount` named `log-reader-shared` and the `ClusterRole` named `limited:log-reader-shared` [already exist](#pre-requisites)):

```yaml
# 1. Set the existing ServiceAccount name from the `shared` namespace
# Example: for read-only log access:
#          $  export SERVICE_ACCOUNT='log-reader-shared'
#
export SERVICE_ACCOUNT='<existing-shared-sa-name>'

# 2. Set the TARGET NAMESPACE to which access is being granted
# Example: to give access to the `arctic` namespace:
#          $  export TARGET_NAMESPACE='arctic'
#
export TARGET_NAMESPACE='<namespace-to-be-accessed>'

# 2. Create the RoleBinding in the target namespace that grants permissions
#    defined in the ClusterRole, to the shared ServiceAccount
#
cat ./reusable-rolebinding.yaml | envsubst | kubectl apply -f -
```

This results in a RoleBinding named: `${SERVICE_ACCOUNT}-rb` in the target namespace, granting the permissions defined in the ClusterRole, to the shared ServiceAccount.

## Pre-Requisites

For **each type of shared access** (e.g. log-reader-shared, etc) in each cluster, create:
- A shared `ServiceAccount` and its associated `Secret`, in the `shared` namespace
- A global `ClusterRole` (no namespace) with the appropriate permissions

> [!IMPORTANT]
> For clarity:
> - Use multiple, dedicated ServiceAccounts to keep access categories distinct, instead of just having one shared SA for all the different roles.
> - Make the SA name short and descriptive of its function, and append "-shared" to the end (e.g. 'log-reader-shared').

1. Shared `ServiceAccount` and its Associated `Secret`

    ```shell
    # 1. Set the SERVICE_ACCOUNT (replace <descriptive-sa-name-here>)
    # Example: for read-only log access, a good name would be: 'log-reader-shared'
    #
    export SERVICE_ACCOUNT='<descriptive-sa-name-here>'

    # 2. Create the SA
    #
    cat ./reusable-serviceaccount.yaml | envsubst | kubectl apply -f -

    # 3. Create the SA Secret
    #
    export BASE64_SECRET=$(head -c 25 /dev/random | shasum -a 256 | head -c 25 | base64)
    cat ./reusable-sa-secret.yaml | envsubst | kubectl apply -f -
    ```

> [!IMPORTANT]
> When creating a new secret, use it to create a corresponding kubeconfig file, and save **a GPG-ENCRYPTED copy** in the security repo. See [config-example-prod](./config-example-prod) as an example, and follow the instructions in the comments. Give a copy to approved users who need access, and provide the [link to the Client Setup instructions](https://github.com/DataONEorg/k8s-cluster/blob/main/authorization/authorization.md#client-setup)

2. Global `ClusterRole` with the Appropriate Permissions

   - Create a new YAML file with the appropriate permissions. Use ./custom-cr-log-reader-shared.yaml as an example template (see the detailed instructions in the comments), and modify the rules as needed for the type of access being granted. 

   - Save to a file named `custom-cr-$SERVICE_ACCOUNT` (example: `custom-cr-log-reader-shared.yaml`), and push to GH.
   - Use it to create the `ClusterRole`:

     ```shell
     # kubectl create -f custom-cr-${SERVICE_ACCOUNT}.yaml
     # Example:
     kubectl create -f custom-cr-log-reader-shared.yaml
     ```

For example, setting `SERVICE_ACCOUNT='log-reader-shared'` and running the above commands should result in the creation of:
- a `ServiceAccount` named `log-reader-shared` (in the `shared` namespace)
- an authentication secret for the `ServiceAccount`, named `log-reader-shared-secret` (in the `shared` namespace)
- a `ClusterRole` named `limited:log-reader-shared`
- a YAML file in this GH repo named: `custom-cr-log-reader-shared.yaml`, defining the `ClusterRole`
- a GPG-encrypted kubeconfig file named `log-reader-shared-dev.gpg` (or `log-reader-shared-prod.gpg` for the prod cluster), in the NCEAS Security repo
