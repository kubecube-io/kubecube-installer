#!/usr/bin/env bash

set -o nounset
set -o pipefail

OPT=$1

function kubecube_uninstall() {
  clog info "uninstalling kubecube"

  clog debug "remove kubecube files"
  rm -rf /etc/kubecube

  clog debug "uninstall kubecueb helm chart release"
  helm uninstall kubecube || true

  clog info "kubecube uninstall success"
}

function kubernetes_uninstall() {
  clog info "uninstalling kubernetes"

  clog debug "kubernetes reset"
  kubeadm reset
  rm -rf /root/.kube

  clog debug "delete residual files of kubernetes"
  rm -rf /etc/kubernetes/
  rm -rf /var/lib/etcd
  rm -rf /var/lib/cni/

  clog debug "delete binaries of kubernetes"
  rm /usr/local/bin/crictl
  rm /usr/local/bin/kubeadm
  rm /usr/local/bin/kubectl
  rm /usr/local/bin/kubelet
  rm /usr/local/bin/helm || true

  clog info "kubernetes uninstall success"
}

function docker_uninstall() {
  clog info "uninstalling docker"

  clog debug "stop docker"
  systemctl stop docker

  clog debug "delete residual files of docker"
  rm -rf /var/lib/docker
  rm /etc/systemd/system/docker.service
  rm /etc/docker/daemon.json
  rm /usr/bin/docker
  rm /usr/bin/dockerd
  umount /var/run/docker/netns/default
  rm -rf /var/run/docker

  clog info "docker uninstall success"
}

function containerd_uninstall() {
    clog info "uninstalling containerd"
    systemctl disable containerd --now
    rm -f /etc/crictl.yaml
    rm -rf /etc/cni
    rm -f /etc/systemd/system/containerd.service
    rm -f /usr/local/sbin/runc
    rm -f /usr/local/bin/containerd-shim-runc-v1
    rm -f /usr/local/bin/critest
    rm -f /usr/local/bin/ctr
    rm -f /usr/local/bin/containerd-shim
    rm -f /usr/local/bin/crictl
    rm -f /usr/local/bin/containerd
    rm -f /usr/local/bin/ctd-decoder
    rm -f /usr/local/bin/containerd-stress
    rm -f /usr/local/bin/containerd-shim-runc-v2
    rm -rf /opt/cni
    rm -rf /opt/containerd
    rm -rf /etc/containerd
    clog info "containerd uninstall success"
}

function clog() {
  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
  case "$1" in
    debug)
      echo -e "$TIMESTAMP \033[36mDEBUG\033[0m $2"
      ;;
    info)
      echo -e "$TIMESTAMP \033[32mINFO\033[0m $2"
      ;;
    warn)
      echo -e "$TIMESTAMP \033[33mWARN\033[0m $2"
      ;;
    error)
      echo -e "$TIMESTAMP \033[31mERROR\033[0m $2"
      ;;
    *)
      ;;
  esac
}

function main() {
  case ${OPT} in
    "kubecube") kubecube_uninstall
    ;;
    "k8s") kubernetes_uninstall
    ;;
    "docker") docker_uninstall
    ;;
    "containerd") containerd_uninstall
    ;;
    "all")
      kubecube_uninstall
      kubernetes_uninstall
      docker_uninstall
      containerd_uninstall
    ;;
    *)
      echo "unknown params, only support: 'kubecube','k8s','docker','containerd','all'"
    ;;
  esac
}

main
