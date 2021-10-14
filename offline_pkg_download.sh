#!/bin/bash

KUBERNETES_VERSION=$1
OS_ARCH=$2

ZONE=cn
DOCKER_VER=19.03.8
OFFLINE_PKG="kubecube_offline_pkg"

function offline_image_download() {
  clog info "downloading images"

  for image in $(cat ./images/v${KUBERNETES_VERSION}/images.list)
  do
    if [[ ${OS_ARCH} == arm64 ]]]; then
      docker pull ${image} --platform=arm64
    else
      docker pull ${image}
    fi
  done

  clog info "archiving images"

  images=""
  for image in $(cat ./images/v${KUBERNETES_VERSION}/images.list)
  do
    images="$images $image"
  done

  docker save -o ${OFFLINE_PKG}/offline_images.tar ${images}
}

function docker_bin_download() {
  if [[ ${OS_ARCH} == amd64 ]]; then
    ARCH=x86_64
  else
    ARCH=aarch64
  fi

  if [[ "$ZONE" == cn ]];then
    DOCKER_URL="https://kubecube.nos-eastchina1.126.net/docker-ce/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
  else
    DOCKER_URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
  fi

  clog info "downloading docker binaries, version $DOCKER_VER"
  if [[ -e /usr/bin/curl ]];then
    curl -C- -O --retry 3 "$DOCKER_URL" || { clog error "downloading docker failed"; exit 1; }
  else
    wget -c "$DOCKER_URL" || { clog error "downloading docker failed"; exit 1; }
  fi
  /bin/mv -f "./docker-$DOCKER_VER.tgz" ${OFFLINE_PKG}
}

function k8s_bin_download() {
  CNI_VERSION="v0.8.2"
  CRICTL_VERSION="v1.17.0"
  RELEASE=v${KUBERNETES_VERSION}
  RELEASE_VERSION="v0.4.0"
  
  clog info "downloading kubernetes: ${KUBERNETES_VERSION} binaries"

  clog debug "downloading cni plugin"

  cd ${OFFLINE_PKG}

  if [[ "$ZONE" == cn ]];then
    curl -L "https://kubecube.nos-eastchina1.126.net/containernetworking/${CNI_VERSION}/cni-plugins-linux-${OS_ARCH}-${CNI_VERSION}.tgz" -o cni-plugins-linux-${OS_ARCH}-${CNI_VERSION}.tgz

    clog debug "downloading crictl"
    curl -L "https://kubecube.nos-eastchina1.126.net/cri-tools/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${OS_ARCH}.tar.gz" -o crictl-${CRICTL_VERSION}-linux-${OS_ARCH}.tar.gz

    clog debug "downloading kubeadm,kubelet,kubectl"
    RELEASE=v${KUBERNETES_VERSION}
    curl -L --remote-name-all https://kubecube.nos-eastchina1.126.net/kubernetes/${RELEASE}/bin/linux/${OS_ARCH}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}

    clog debug "downloading kubelet config service"
    RELEASE_VERSION="v0.4.0"
    curl -sSL "https://kubecube.nos-eastchina1.126.net/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" -o kubelet.service
    curl -sSL "https://kubecube.nos-eastchina1.126.net/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" -o 10-kubeadm.conf
  else
    curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${OS_ARCH}-${CNI_VERSION}.tgz"  -o cni-plugins-linux-${OS_ARCH}-${CNI_VERSION}.tgz

    clog debug "downloading crictl"
    curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${OS_ARCH}.tar.gz" -o crictl-${CRICTL_VERSION}-linux-${OS_ARCH}.tar.gz

    clog debug "downloading kubeadm,kubelet,kubectl"
    RELEASE=v${KUBERNETES_VERSION}
    cd ${path}
    curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${OS_ARCH}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}

    clog debug "downloading kubelet config service"
    RELEASE_VERSION="v0.4.0"
    curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" -o kubelet.service
    curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" -o 10-kubeadm.conf
  fi

  cd ..
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
  mkdir -p ${OFFLINE_PKG}

  docker_bin_download
  k8s_bin_download
  offline_image_download
}

main