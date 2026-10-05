#!/usr/bin/env bash

SECRETS_KUBERNETES_DIR="/var/run/secrets/kubernetes.io/serviceaccount"
DOCKER_VERNEMQ_KUBERNETES_CLUSTER_NAME=${DOCKER_VERNEMQ_KUBERNETES_CLUSTER_NAME:-cluster.local}

if [ -d "${SECRETS_KUBERNETES_DIR}" ] ; then
    # Let's get the namespace if it isn't set
    DOCKER_VERNEMQ_KUBERNETES_NAMESPACE=${DOCKER_VERNEMQ_KUBERNETES_NAMESPACE:-$(cat "${SECRETS_KUBERNETES_DIR}/namespace")}
fi

insecure=""
if env | grep "DOCKER_VERNEMQ_KUBERNETES_INSECURE" -q; then
    echo "Using curl with \"--insecure\" argument to access kubernetes API without matching SSL certificate"
    insecure="--insecure"
fi

function k8sCurlGet () {
    local urlPath=$1

    local hostname="kubernetes.default.svc.${DOCKER_VERNEMQ_KUBERNETES_CLUSTER_NAME}"
    local certsFile="${SECRETS_KUBERNETES_DIR}/ca.crt"
    local token=$(cat ${SECRETS_KUBERNETES_DIR}/token)
    local header="Authorization: Bearer ${token}"
    local url="https://${hostname}/${urlPath}"

    curl -sS ${insecure} --cacert ${certsFile} -H "${header}" ${url} \
      || ( echo "### Error on accessing URL ${url}" )
}

try_join() {
  local exit_code=0
  if env | grep "DOCKER_VERNEMQ_DISCOVERY_KUBERNETES" -q; then
      # Let's set our nodename correctly
      # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#list-pod-v1-core
      podList=$(k8sCurlGet "api/v1/namespaces/${DOCKER_VERNEMQ_KUBERNETES_NAMESPACE}/pods?labelSelector=${DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR}")
      kube_pod_names=$(echo ${podList} | jq '.items[].spec.hostname' | sed 's/"//g' | tr '\n' ' ' | sed 's/ *$//')
      VERNEMQ_KUBERNETES_SUBDOMAIN=${DOCKER_VERNEMQ_KUBERNETES_SUBDOMAIN:-$(echo ${podList} | jq '.items[0].spec.subdomain' | tr '\n' '"' | sed 's/"//g')}

      for kube_pod_name in $kube_pod_names; do
          if [[ $kube_pod_name == "null" ]]; then
              echo "Kubernetes discovery selected, but no pods found. Maybe we're the first?"
              echo "Anyway, we won't attempt to join any cluster."
              exit 0
          fi

          if [[ $kube_pod_name != "$MY_POD_NAME" ]]; then
              discoveryHostname="${kube_pod_name}.${VERNEMQ_KUBERNETES_SUBDOMAIN}.${DOCKER_VERNEMQ_KUBERNETES_NAMESPACE}.svc.${DOCKER_VERNEMQ_KUBERNETES_CLUSTER_NAME}"
              echo "Will join an existing Kubernetes cluster with discovery node at ${discoveryHostname}"
              vmq-admin cluster show | grep "VerneMQ@${discoveryHostname}" > /dev/null || exit_code=$?
              if [ $exit_code -eq 0 ]; then
                  echo "We have already joined the cluster - no extra work required."
                  exit 0
              else
                  echo "We have yet to join the cluster - attempting manual join..."
                  vmq-admin cluster join discovery-node="VerneMQ@${discoveryHostname}"
                  sleep 2
              fi
              break
          fi
      done
  else
      exit 0
  fi
}

while true
do
    try_join
done;