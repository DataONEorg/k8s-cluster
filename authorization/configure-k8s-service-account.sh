#!/bin/bash

# This script creates the authorization needed to run an app on the DataONE k8s cluster.
# A k8s namespace, service account and kubectl context are createdi, and a default set of RBAC rules are applied.
set -e
set -o pipefail

# The namespace and serviceaccount will have the same name as the application.
if [[ -z "$1" ]] ; then
 echo "usage: $0 application-name"
 exit 1
fi

SERVICE_ACCOUNT_NAME=$1
NAMESPACE="$1"
TARGET_FOLDER="${HOME}/.kube"
CONFIG="${TARGET_FOLDER}/config"
KUBECFG_FILE_NAME="${TARGET_FOLDER}/${SERVICE_ACCOUNT_NAME}.config"
TODAY=$(date +'%Y-%m-%d-%H%M%S')

create_target_folder() {
    echo -n "Creating target directory to hold files in ${TARGET_FOLDER}..."
    mkdir -p "${TARGET_FOLDER}"
    printf "done"
}

create_namespace() {
    echo -e "\\nCreating the namespace ${NAMESPACE}"
    kubectl create namespace "${NAMESPACE}"
}

create_service_account() {
    echo -e "\\nCreating a service account in ${NAMESPACE} namespace: ${SERVICE_ACCOUNT_NAME}"
    kubectl create sa "${SERVICE_ACCOUNT_NAME}" --namespace "${NAMESPACE}"
}

get_secret_name_from_service_account() {
    echo -e "\\nGetting secret of service account ${SERVICE_ACCOUNT_NAME} on ${NAMESPACE}"
    SECRET_NAME=$(kubectl get sa "${SERVICE_ACCOUNT_NAME}" --namespace="${NAMESPACE}" -o json | jq -r .secrets[].name)
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

    # Set up the config
    echo -e "\\nPreparing k8s-${SERVICE_ACCOUNT_NAME}-conf"
    echo -n "Setting a cluster entry in kubeconfig..."
    kubectl config set-cluster "${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --server="${ENDPOINT}" \
    --certificate-authority="${TARGET_FOLDER}/ca.crt" \
    --embed-certs=true

    echo -n "Setting token credentials entry in kubeconfig..."
    kubectl config set-credentials \
    "${SERVICE_ACCOUNT_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --token="${USER_TOKEN}" \
    --cluster="${CLUSTER_NAME}"

    echo -n "Setting a context entry in kubeconfig..."
    kubectl config set-context \
    "${SERVICE_ACCOUNT_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --user="${SERVICE_ACCOUNT_NAME}" \
    --namespace="${NAMESPACE}"

    echo -n "Setting the current-context in the kubeconfig file..."
    kubectl config use-context "${SERVICE_ACCOUNT_NAME}" \
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
    cat application-context.yaml | SERVICE_ACCOUNT=${SERVICE_ACCOUNT_NAME} envsubst | kubectl apply -f -
}

echo "Starting on ${TODAY}..."
create_target_folder
create_namespace
create_service_account
get_secret_name_from_service_account
extract_ca_crt_from_secret
get_user_token_from_secret
set_kube_config_values
flatten_config
apply_rbac

echo -e "\\nAll done! Test with:"
echo "KUBECONFIG=${KUBECFG_FILE_NAME} kubectl get pods"
KUBECONFIG=${KUBECFG_FILE_NAME} kubectl get pods

