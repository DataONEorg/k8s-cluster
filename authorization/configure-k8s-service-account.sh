#!/bin/bash

# This script creates the authorization needed to run an app on the DataONE k8s cluster.
# A k8s namespace, service account and kubectl context are created, and a default set of RBAC rules are applied.
set -e
set -o pipefail

# The namespace and serviceaccount will have the same name as the application.
# Config files will prefix these with cluster-type (dev or prod)
if [[ -z "$1" ]] ; then
 echo "usage: $0 application-name cluster-type"
 exit 1
fi

if [[ -z "$2" ]] ; then
  CLUSTER_TYPE="dev"
else 
  CLUSTER_TYPE=$2
fi

# Must be run as admin in order to create all required resources!
#
[[ "$CLUSTER_TYPE" == "prod" ]] && ctx_expected="prod-k8s"
[[ "$CLUSTER_TYPE" == "dev" ]] && ctx_expected="dev-k8s"

if [[ -z "$ctx_expected" ]]; then
  echo "❌ CLUSTER_TYPE must be 'prod' or 'dev'"; exit 1
fi

echo "Using CLUSTER_TYPE: ${CLUSTER_TYPE}"

ctx=$(kubectl config current-context)

if [[ "$ctx" != "$ctx_expected" ]] ; then
  echo "❌ Wrong context (${ctx}). Must use $CLUSTER_TYPE admin context (${ctx_expected}) to run this script!"
  exit 1
fi

SERVICE_ACCOUNT_NAME=$1
NAMESPACE="$1"
TARGET_FOLDER="${HOME}/.kube"
CONFIG="${TARGET_FOLDER}/config-${CLUSTER_TYPE}"
KUBECFG_FILE_NAME="${TARGET_FOLDER}/${SERVICE_ACCOUNT_NAME}-${CLUSTER_TYPE}.config"
TODAY=$(date +'%Y-%m-%d-%H%M%S')

create_target_folder() {
    echo -n "Creating target directory to hold files in ${TARGET_FOLDER}..."
    mkdir -p "${TARGET_FOLDER}"
    printf "done"
}

create_namespace() {
    if [ $(kubectl get namespaces ${NAMESPACE} 2>&1 | grep -c "NotFound") -gt 0 ]; then
      echo -e "\\nCreating the namespace ${NAMESPACE}"
      kubectl create namespace "${NAMESPACE}"
    else
      echo -e "\\n⚠️ Namespace ${NAMESPACE} already exists, skipping creation."
    fi
}

create_service_account() {
    if [ $(kubectl get sa --namespace ${NAMESPACE} | grep -c "${SERVICE_ACCOUNT_NAME}") -eq 0 ]; then
        echo -e "\\nCreating a service account in ${NAMESPACE} namespace: ${SERVICE_ACCOUNT_NAME}"
        kubectl create sa "${SERVICE_ACCOUNT_NAME}" --namespace "${NAMESPACE}" --save-config
    else
      echo -e "\\n⚠️ service account ${SERVICE_ACCOUNT_NAME} already exists in namespace ${NAMESPACE};"
      echo "    SKIPPING creation of service account, secret, and kubeconfig file!"
      echo "    If you need these re-created, please delete the service account and try again;"
      echo "    use: $ kubectl delete sa ${SERVICE_ACCOUNT} --namespace ${NAMESPACE}"
      skip_sa="true"
    fi
}

create_sa_secret() {
    # Create a secret to be used to identify the SA
    # As of k8s 1.22 a token is not automatically attached to a SA, so needs to be manually created
    # See: https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
    export BASE64_SECRET=$(head -c 25 /dev/random | shasum -a 256 | head -c 25 | base64)
    cat sa-token.yaml | SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} envsubst | kubectl apply -f -
}

get_secret_name_from_service_account() {
    echo -e "\\nGetting secret of service account ${SERVICE_ACCOUNT_NAME} on ${NAMESPACE}"
    #SECRET_NAME=$(kubectl get sa "${SERVICE_ACCOUNT_NAME}" --namespace="${NAMESPACE}" -o json | jq -r .secrets[].name)
    SECRET_NAME="${SERVICE_ACCOUNT_NAME}-secret"
    echo "Secret name: ${SECRET_NAME}"
}

extract_ca_crt_from_secret() {
    echo -e -n "\\nExtracting ca.crt from secret..."
    kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq \
    -r '.data["ca.crt"]' | base64 -d > "${TARGET_FOLDER}/ca.crt"
    printf "done"
}

get_user_token_from_secret() {
    echo -e -n "\\nGetting user token from secret..."
    USER_TOKEN=$(kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq -r '.data["token"]' | base64 -d)
    printf "done"
}

set_kube_config_values() {
    context=$(kubectl config current-context)
    echo -e "\\nSetting current context to: $context"

    CLUSTER_NAME=$(kubectl config get-contexts "$context" | awk '{print $3}' | tail -n 1)
    echo "Cluster name: ${CLUSTER_NAME}"

    ENDPOINT=$(kubectl config view \
    -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
    echo "Endpoint: ${ENDPOINT}"
    echo "Target Folder: ${TARGET_FOLDER}"

    # Set up the config
    echo -e "\\nPreparing ${KUBECFG_FILE_NAME}"
    echo -n "Setting a cluster entry in kubeconfig..."
    kubectl config set-cluster "${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --server="${ENDPOINT}" \
    --certificate-authority="${TARGET_FOLDER}/ca.crt" \
    --embed-certs=true

    echo -n "Setting token credentials entry in kubeconfig..."
    kubectl config set-credentials \
    "${CLUSTER_TYPE}-${SERVICE_ACCOUNT_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --token="${USER_TOKEN}" \
    --cluster="${CLUSTER_NAME}"

    echo -n "Setting a context entry in kubeconfig..."
    kubectl config set-context \
    "${CLUSTER_TYPE}-${SERVICE_ACCOUNT_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --user="${CLUSTER_TYPE}-${SERVICE_ACCOUNT_NAME}" \
    --namespace="${NAMESPACE}"

    echo -n "Setting the current-context in the kubeconfig file..."
    kubectl config use-context "${CLUSTER_TYPE}-${SERVICE_ACCOUNT_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --cluster="${CLUSTER_NAME}"
}

flatten_config() {
    # To merge two config files, add them both to the KUBECONFIG list, then use `--flatten`
    echo -e "\\nFlattening and merging the ${NAMESPACE} config"
    cp ${CONFIG} ${CONFIG}.bak-${TODAY}
    KUBECONFIG=${CONFIG}:${KUBECFG_FILE_NAME} kubectl config view --flatten > ${CONFIG}-flattened-${NAMESPACE}
    mv ${CONFIG}-flattened-${NAMESPACE} ${CONFIG}
}

apply_rbac() {
    echo -e "\\nApplying RBAC rules for service account ${SERVICE_ACCOUNT_NAME} in namespace ${NAMESPACE}"
    cat application-context.yaml | SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} envsubst | kubectl apply -f -
}

echo "Starting on ${TODAY}..."
create_target_folder
create_namespace
skip_sa="false"
TEST_CFG=${CONFIG}
create_service_account
if [[ "$skip_sa" != "true" ]] ; then
    create_sa_secret
    get_secret_name_from_service_account
    extract_ca_crt_from_secret
    get_user_token_from_secret
    set_kube_config_values
    flatten_config
    TEST_CFG=${KUBECFG_FILE_NAME}
fi
apply_rbac

echo -e "\\nAll done! Test with:"
echo "KUBECONFIG=${TEST_CFG} kubectl get sa"
KUBECONFIG=${TEST_CFG} kubectl get sa
