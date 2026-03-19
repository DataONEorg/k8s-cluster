# Limited Access

Limited access can be granted by giving someone access to a special, shared `ServiceAccount` that has the appropriate `ClusterRole` permissions assigned via a `RoleBinding` in the target namespace. See the [Pre-Requisites section](#pre-requisites) for details on initial setup of the `ServiceAccount` and `ClusterRole` for each type of access

For example, to give read-only access to logs in the `arctic` namespace (assuming the `ServiceAccount` named `log-reader-shared` and the `ClusterRole` named `limited:log-reader-shared` already exist):

```yaml
    # 1. Set the existing SERVICE_ACCOUNT_NAME from the `shared` namespace
    # Example: for read-only log access:
    #          $  export SERVICE_ACCOUNT_NAME='log-reader-shared'
    #
    export SERVICE_ACCOUNT_NAME='<existing-shared-sa-name>'

    # 2. Set the TARGET NAMESPACE to which access is being granted
    # Example: to give access to the `arctic` namespace:
    #          $  export TARGET_NAMESPACE='arctic'
    #
    export TARGET_NAMESPACE='<namespace-to-be-accessed>'

  # 2. Create the SA
  #
    cat ./reusable-rolebinding.yaml | \
        SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} \
        TARGET_NAMESPACE=${TARGET_NAMESPACE} \
        envsubst | kubectl apply -f -
```

## Pre-Requisites

For **each type of shared access** (e.g. log-reader-shared, etc) in each cluster, create:
- A shared `ServiceAccount` and its associated `Secret`, in the `shared` namespace
- A global `ClusterRole` (no namespace) with the appropriate permissions

> [!IMPORTANT]
> For clarity, try to keep shared categories distinct, instead of just having one shared ServiceAccount for all the different roles

1. Shared `ServiceAccount` and its Associated `Secret`

    ```shell
    # 1. Set the SERVICE_ACCOUNT_NAME (replace <descriptive-sa-name-here>)
    # Example: for read-only log access, a good name would be: 'log-reader-shared'
    #
    export SERVICE_ACCOUNT_NAME='<descriptive-sa-name-here>'

    # 2. Create the SA
    #
    cat ./reusable-serviceaccount.yaml | SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} envsubst | kubectl apply -f -

    # 3. Create the SA Secret
    #
    export BASE64_SECRET=$(head -c 25 /dev/random | shasum -a 256 | head -c 25 | base64)
    cat ./reusable-sa-token.yaml | SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} envsubst | kubectl apply -f -
    ```

> [!IMPORTANT]
> When creating a new secret, use it to create a corresponding kube congig file, and save **a gpg-encrypted copy** in the security repo. See [config-example-prod](./config-example-prod) as an example. Give a copy to whoever needs access, and give them the [link to the Client Setup instructions](https://github.com/DataONEorg/k8s-cluster/blob/main/authorization/authorization.md#client-setup)

2. Global `ClusterRole` with the Appropriate Permissions

   - Create a new yaml file with the appropriate permissions. Note that it's OK to hard-code the $SERVICE_ACCOUNT name, since this is a custom ClusterRole used only for that particular SA. Example:

     ```yaml
     ## Read-only access to pods/logs. SA named 'log-reader-shared' already created
     ##
     kind: ClusterRole
     apiVersion: rbac.authorization.k8s.io/v1
     metadata:
       ## Use name: limited:$SERVICE_ACCOUNT -- and it's OK to hard-code $SERVICE_ACCOUNT name,
       ## since this is a custom ClusterRole used only for that SA
       name: limited:log-reader-shared
     rules:
       - apiGroups: [""]
         resources: ["pods", "pods/log"]
         verbs: ["get", "list", "watch"]
     ```

   - Save to a file named `custom-cr-$SERVICE_ACCOUNT_NAME` (example: `custom-cr-log-reader-shared.yaml`), and push to GH.
   - Use it to create the `ClusterRole`:

     ```shell
     # kubectl create -f custom-cr-${SERVICE_ACCOUNT_NAME}.yaml
     # Example:
     kubectl create -f custom-cr-log-reader-shared.yaml
     ```

For example, setting `SERVICE_ACCOUNT_NAME='log-reader-shared'` and running the above commands would result in the creation of:
- a `ServiceAccount` named `log-reader-shared` (in the `shared` namespace)
- an authentication secret for the `ServiceAccount`, named `log-reader-shared-secret` (in the `shared` namespace)
- a yaml file named: `custom-cr-log-reader-shared.yaml`. defining a `ClusterRole`, and
- a `ClusterRole` named `limited:log-reader-shared`
