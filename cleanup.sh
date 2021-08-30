#!/usr/bin/env bash

source /etc/kubecube/manifests/utils.sh

set -o errexit
set -o nounset
set -o pipefail

OPT=$1

function kubecube_uninstall() {
  return
}

function kubernetes_uninstall() {
  return
}

function docker_uninstall() {
  return
}

function main() {
  case ${OPT} in
    "kubecube") echo "1"
    ;;
    "k8s") echo "2"
    ;;
    "docker") echo "3"
    ;;
    *)
      echo "unknown params, only support: 'kubecube','k8s','docker'"
  esac
}

main
