#!/usr/bin/env bash
set -e
set -o pipefail

function destroy_all() {
    /usr/local/bin/skipper make destroy
}

function set_dns() {
  API_VIP=$(ip route show dev ${INSTALLER_IMAGE:-"tt0"} | cut -d\  -f7)
  echo "server=/api.${CLUSTER_DOMAIN}/${API_VIP}" | sudo tee -a /etc/NetworkManager/dnsmasq.d/openshift-${CLUSTER_NAME}.conf
  sudo systemctl reload NetworkManager
}

function wait_for_cluster() {
  SLEEP=5
  # Timeout 60 minutes
  RETRIES=60*60/${SLEEP}
  echo "Waiting till we have 3 masters"
  until [ $RETRIES -gt 0 ] || [ $(kubectl --kubeconfig=build/kubeconfig get nodes | grep master | grep -v NotReady | grep Ready | wc -l) -eq 3 ]; do
      sleep ${SLEEP}s
      RETRIES=$((RETRIES-1))
      oc --kubeconfig=build/kubeconfig get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc --kubeconfig=build/kubeconfig adm certificate approve
  done
  if [ $RETRIES -eq 0 ]; then
    echo "Timeout reached, cluster still is down"
    exit 1
  fi
  echo "Got 3 ready masters"
  echo -e "$(kubectl --kubeconfig=build/kubeconfig get nodes)"
}


#TODO ADD ALL RELEVANT OS ENVS
function run() {
  /usr/local/bin/skipper make $1 NUM_MASTERS=$NUM_MASTERS NUM_WORKERS=$NUM_WORKERS KUBECONFIG=$PWD/minikube_kubeconfig BASE_DOMAIN=$BASE_DOMAIN CLUSTER_NAME=$CLUSTER_NAME
  if [ "$1" = "run_full_flow_with_install" ]; then
    wait_for_cluster
  fi
}


function run_skipper_make_command() {
    /usr/local/bin/skipper make $1
}


function run_without_os_envs() {
  run_skipper_make_command $1
}
