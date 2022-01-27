#!/usr/bin/env bash

set -e

BASE="/etc/kubecube"
K8S_REGISTR="k8s.gcr.io"
CN_K8S_REGISTR="registry.cn-hangzhou.aliyuncs.com/google_containers"

source /etc/kubecube/manifests/utils.sh

function containerd_installed(){
  CONTAINERD_VERSION=1.5.5
  #disable docker if exist
  systemctl disable docker --now || true

  if command -v crictl >/dev/null 2>&1; then
    clog info 'exists containerd'
    return
  fi

  os_arch="amd64"
  if [[ $(arch) == aarch64 ]]; then
    os_arch="arm64"
  fi

  wget https://kubecube.nos-eastchina1.126.net/containerd/"$CONTAINERD_VERSION"/cri-containerd-cni-"$CONTAINERD_VERSION"-linux-$os_arch.tar.gz -O containerd.tar.gz

  tar -C / -xzf containerd.tar.gz
  rm -rf containerd.tar.gz
  echo "export PATH=$PATH:/usr/local/bin:/usr/local/sbin" >> /etc/profile
  source /etc/profile
  if command -v crictl >/dev/null 2>&1; then
    clog info "install containerd success"
  else
    clog error "install containerd fail"
    exit 1
  fi
}

function containerd_configuration() {
  #configuration net
  cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
  modprobe overlay
  modprobe br_netfilter

  cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system

  #configuration containerd
  mkdir /etc/containerd || true
  containerd config default > /etc/containerd/config.toml
  sed -i '/SystemdCgroup = false/d' /etc/containerd/config.toml
  sed -i '/containerd.runtimes.runc.options/a\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' /etc/containerd/config.toml
  systemctl daemon-reload
  systemctl enable containerd --now || true

  #configuration pause
  if [[ "$ZONE" == cn ]];then
    sed -i 's|k8s.gcr.io/pause|registry.cn-hangzhou.aliyuncs.com/k8sxio/pause|' /etc/containerd/config.toml
    ctr -n k8s.io i pull registry.cn-hangzhou.aliyuncs.com/k8sxio/pause:3.5 || true
    ctr -n k8s.io i tag registry.cn-hangzhou.aliyuncs.com/k8sxio/pause:3.5 k8s.gcr.io/pause:3.5 || true
  fi
}

function k8s_bin_get() {
  [[ (-f "/usr/local/bin/kubelet") && (-f "/usr/local/bin/kubeadm") && (-f "/usr/local/bin/kubectl") && (-f "/usr/local/bin/crictl") ]] && { clog warn "kubernetes binaries existed"; return 0; }

  os_arch="amd64"
  if [[ $(arch) == aarch64 ]]; then
      os_arch="arm64"
  fi

  DOWNLOAD_DIR=/usr/local/bin
  RELEASE=v${KUBERNETES_VERSION}
  RELEASE_VERSION="v0.4.0"

  mkdir -p $DOWNLOAD_DIR
  mkdir -p /etc/systemd/system/kubelet.service.d

  if [[ "$OFFLINE_INSTALL" == "true" ]]; then
    k8s_bin_local
  else
    k8s_bin_download
  fi
}

function k8s_bin_local() {
  clog info "get k8s bin from local"

  clog debug "get kubeadm,kubelet,kubectl"
  mv ${OFFLINE_PKG_PATH}/kubeadm $DOWNLOAD_DIR
  mv ${OFFLINE_PKG_PATH}/kubelet $DOWNLOAD_DIR
  mv ${OFFLINE_PKG_PATH}/kubectl $DOWNLOAD_DIR
  chmod +x {$DOWNLOAD_DIR/kubeadm,$DOWNLOAD_DIR/kubelet,$DOWNLOAD_DIR/kubectl}

  clog debug "config for kubelet service"
  cat ${OFFLINE_PKG_PATH}/kubelet.service | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
  cat ${OFFLINE_PKG_PATH}/10-kubeadm.conf | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
}

function k8s_bin_download() {
  clog info "downloading kubernetes: ${KUBERNETES_VERSION} binaries"

  if [[ "$ZONE" == cn ]];then
    clog debug "downloading kubeadm,kubelet,kubectl"
    RELEASE=v${KUBERNETES_VERSION}
    cd $DOWNLOAD_DIR
    curl -L --remote-name-all https://kubecube.nos-eastchina1.126.net/kubernetes/${RELEASE}/bin/linux/${os_arch}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}

    clog debug "config for kubelet service"
    RELEASE_VERSION="v0.4.0"
    curl -sSL "https://kubecube.nos-eastchina1.126.net/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
    curl -sSL "https://kubecube.nos-eastchina1.126.net/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sed -i '2a\Environment="KUBELET_EXTRA_ARGS=--runtime-cgroups=/system.slice/containerd.service --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  else
    clog debug "downloading kubeadm,kubelet,kubectl"
    RELEASE=v${KUBERNETES_VERSION}
    cd $DOWNLOAD_DIR
    curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${os_arch}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}

    clog debug "config for kubelet service"
    RELEASE_VERSION="v0.4.0"
    curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
    curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sed -i '2a\Environment="KUBELET_EXTRA_ARGS=--runtime-cgroups=/system.slice/containerd.service --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  fi
}

function images_download() {
  if [[ "$OFFLINE_INSTALL" == "true" ]]; then
      clog info "loading image form local"
      docker load < ${OFFLINE_PKG_PATH}/offline_images.tar
  else
      clog info "downloading images"

      # download k8s images
      if [[ "$INSTALL_KUBERNETES" == "true" ]]; then
        for image in $(cat /etc/kubecube/manifests/images/k8s/v${KUBERNETES_VERSION}/images.list)
        do
          ctr i pull ${image}
        done
      fi

      # downloads image need by cube pivot cluster
      if [[ "$INSTALL_KUBECUBE_PIVOT" == "true" ]]; then
        for image in $(cat /etc/kubecube/manifests/images/cube-pivot/images.list)
        do
          ctr i pull ${image}
        done
      fi

      # downloads image need by cube member cluster
      if [[ "$INSTALL_KUBECUBE_MEMBER" == "true" ]]; then
        for image in $(cat /etc/kubecube/manifests/images/cube-member/images.list)
        do
          ctr pull ${image}
        done
      fi
  fi
}

function preparation() {
  clog info "doing previous preparation"

#  clog debug "close firewall and selinux"
#  systemctl stop firewalld.service
#  systemctl disable firewalld.service
#  sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
#  setenforce 0 || true # ignore error

  clog debug "closing swap"
  swapoff -a
  sed -i '/swap/s/^/#/g' /etc/fstab

  clog debug "config kernel params, passing bridge flow of IPv4 to iptables chain"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
  modprobe br_netfilter
  sysctl -p /etc/sysctl.d/k8s.conf
  echo "1" > /proc/sys/net/ipv4/ip_forward

  clog info "enable kubelet service"
  systemctl enable --now kubelet
}

function make_cluster_configuration (){
  clog info "make configuration for kubeadm"

  mkdir -p /etc/cube/kubeadm

  REGISTRY=${K8S_REGISTR}
  if [[ "$ZONE" == cn ]];then
    REGISTRY=${CN_K8S_REGISTR}
  fi

API_SERVER_CONF=$(cat <<- EOF
# set control plane components listen on LOCAL_IP
controllerManager:
  extraArgs:
    bind-address: ${LOCAL_IP}
scheduler:
  extraArgs:
    bind-address: ${LOCAL_IP}
imageRepository: ${REGISTRY}
EOF
)
# enable metrics endpoint on all interfaces
KUBE_PROXY_CONF=$(cat <<- EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
EOF
)

if [ -z ${CONTROL_PLANE_ENDPOINT} ]; then
  clog debug "vip not be set, use node ip"
  CONTROL_PLANE_ENDPOINT=${LOCAL_IP}
fi

cat >/etc/cube/kubeadm/init.config <<EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  name: containerd
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION}
controlPlaneEndpoint: ${CONTROL_PLANE_ENDPOINT}
${API_SERVER_CONF}
---
${KUBE_PROXY_CONF}
EOF
}

function Install_Kubernetes_Master (){
  clog info "init kubernetes, version: ${KUBERNETES_VERSION}"

  if [ ${NODE_MODE} = "master" ];then
    kubeadm init --config=/etc/cube/kubeadm/init.config

  elif [ ${NODE_MODE} = "control-plane-master" ];then
    kubeadm init --config=/etc/cube/kubeadm/init.config --upload-certs
  fi

  mkdir -p ${HOME}/.kube
  cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
  chown $(id -u):$(id -g) ${HOME}/.kube/config

  clog debug "installing calico"
  kubectl apply -f /etc/kubecube/manifests/calico/calico.yaml > /dev/null

  sleep 7 >/dev/null
  clog debug "inspect node"
  kubectl get node

  sleep 7 >/dev/null
  clog debug "inspect pod"
  kubectl get pod --all-namespaces

  sleep 7 >/dev/null
  clog deub "inspect service"
  kubectl get svc --all-namespaces

  clog info "kubernetes ${KUBERNETES_VERSION} deploy completed"
}

function Install_Kubernetes_Node (){
  clog info "init kubernetes, version：${KUBERNETES_VERSION}"

  if [ ! -z ${ACCESS_PASSWORD} ]; then
    clog info "access master node use password"
    TOKEN=$(sshpass -p ${ACCESS_PASSWORD} ssh -p ${SSH_PORT} ${SSH_USER}@${MASTER_IP} "kubeadm token create --ttl=10m")
    Hash=$(sshpass -p ${ACCESS_PASSWORD} ssh -p ${SSH_PORT} ${SSH_USER}@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
    if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
        CertificateKey=$(sshpass -p ${ACCESS_PASSWORD} ssh -p ${SSH_PORT} ${SSH_USER}@${MASTER_IP} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
    fi
  elif [ ! -z ${ACCESS_PRIVATE_KEY_PATH} ]; then
    clog info "access master node use private key"
    TOKEN=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" ${SSH_USER}@${MASTER_IP} -p ${SSH_PORT} "kubeadm token create --ttl=10m")
    Hash=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" ${SSH_USER}@${MASTER_IP} -p ${SSH_PORT} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
    if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
        CertificateKey=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} ${SSH_USER}@${MASTER_IP} -p ${SSH_PORT} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
    fi
  else
    clog error "ACCESS_PASSWORD or ACCESS_PRIVATE_KEY_PATH must be specified"
  fi

  if [ ${NODE_MODE} = "node-join-control-plane" ]; then
    clog info "node join control plane as master"
    kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${Hash} --control-plane --certificate-key ${CertificateKey}
    mkdir -p ${HOME}/.kube
    cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
    chown $(id -u):$(id -g) ${HOME}/.kube/config
  elif [ ${NODE_MODE} = "node-join-master" ]; then
    clog info "node join cluster as worker"
    kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${Hash}
    if [ ! -z ${ACCESS_PASSWORD} ]; then
      sshpass -p ${ACCESS_PASSWORD} ssh -p ${SSH_PORT} ${SSH_USER}@${MASTER_IP} "kubectl label nodes $(hostname) node-role.kubernetes.io/node="
    else
      ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" ${SSH_USER}@${MASTER_IP} -p ${SSH_PORT} "kubectl label nodes $(hostname) node-role.kubernetes.io/node="
    fi
      mkdir -p ${HOME}/.kube
      cp -i /etc/kubernetes/kubelet.conf ${HOME}/.kube/config
      chown $(id -u):$(id -g) ${HOME}/.kube/config
  fi
}

function Main() {
  mkdir -p /etc/kubecube/down
  mkdir -p /etc/kubecube/bin

  params_process
  containerd_installed
  containerd_configuration
  k8s_bin_get
  images_download

  if [[ ${PRE_DOWNLOAD} = "true" ]]; then
    exit 0
  fi

  preparation
  make_cluster_configuration

  clog info "installing node MODE: ${NODE_MODE}"

  if [ ${NODE_MODE} = "master" -o ${NODE_MODE} = "control-plane-master" ];then
    Install_Kubernetes_Master
  elif [ ${NODE_MODE} = "node-join-control-plane" -o ${NODE_MODE} = "node-join-master" ]; then
    Install_Kubernetes_Node
  fi
}

Main