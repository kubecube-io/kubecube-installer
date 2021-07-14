#!/bin/bash

set -e

DOCKER_VER=19.03.8
OFFLINE_INSTALL="true"
BASE="/etc/kubecube"
K8S_REGISTR="k8s.gcr.io"
CN_K8S_REGISTR="registry.cn-hangzhou.aliyuncs.com/google_containers"

source /etc/kubecube/manifests/utils.sh

function offline_pkg_download() {
  if [ -e "${BASE}/packages" ]; then
    clog warn "offline packages already existed"
  else
    clog info "download offline packages"
    wget https://gitee.com/kubecube/packages/repository/archive/master.zip -O packages.zip
    unzip packages.zip -d ${BASE}/ > /dev/null
  fi
}

function docker_bin_get() {
  if [[ -f "$BASE/down/docker-${DOCKER_VER}.tgz" ]];then
    clog warn "docker binaries already existed"
  else
    if [[ "$OFFLINE_INSTALL" == "true" ]]; then
      clog info "get docker binary from local"
      /bin/mv -f "${BASE}/packages/docker-ce/linux/static/stable/$(arch)/docker-$DOCKER_VER.tgz" "$BASE/down"
    else
      docker_bin_download
    fi
  fi

  tar zxf "$BASE/down/docker-$DOCKER_VER.tgz" -C "$BASE/down" && \
  /bin/cp -f "$BASE"/down/docker/* "$BASE/bin" && \
  /bin/mv -f "$BASE"/down/docker/* /usr/bin
#  ln -sf /usr/bin/docker /bin/docker
}

function docker_bin_download() {
  if [[ "$ZONE" == cn ]];then
    DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/$(arch)/docker-${DOCKER_VER}.tgz"
  else
    DOCKER_URL="https://download.docker.com/linux/static/stable/$(arch)/docker-${DOCKER_VER}.tgz"
  fi

  clog info "downloading docker binaries, version $DOCKER_VER"
  if [[ -e /usr/bin/curl ]];then
    curl -C- -O --retry 3 "$DOCKER_URL" || { clog error "downloading docker failed"; exit 1; }
  else
    wget -c "$DOCKER_URL" || { clog error "downloading docker failed"; exit 1; }
  fi
  /bin/mv -f "./docker-$DOCKER_VER.tgz" "$BASE/down"
}

function install_docker() {
  # check if a container runtime is already installed
  systemctl status docker|grep Active|grep -q running && { clog warn "docker is already running."; return 0; }

  clog debug "generate docker service file"

  # config docker service for systemd
  if [[ $(arch) == aarch64 ]]; then
  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
[Service]
Environment="PATH=/usr/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/usr/bin/dockerd
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
  else
  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
[Service]
Environment="PATH=/usr/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStartPre=/sbin/iptables -F
ExecStartPre=/sbin/iptables -X
ExecStartPre=/sbin/iptables -F -t nat
ExecStartPre=/sbin/iptables -X -t nat
ExecStartPre=/sbin/iptables -F -t raw
ExecStartPre=/sbin/iptables -X -t raw
ExecStartPre=/sbin/iptables -F -t mangle
ExecStartPre=/sbin/iptables -X -t mangle
ExecStart=/usr/bin/dockerd
ExecStartPost=/sbin/iptables -P INPUT ACCEPT
ExecStartPost=/sbin/iptables -P OUTPUT ACCEPT
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
  fi

  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
[Service]
Environment="PATH=/usr/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStartPre=/sbin/iptables -F
ExecStartPre=/sbin/iptables -X
ExecStartPre=/sbin/iptables -F -t nat
ExecStartPre=/sbin/iptables -X -t nat
ExecStartPre=/sbin/iptables -F -t raw
ExecStartPre=/sbin/iptables -X -t raw
ExecStartPre=/sbin/iptables -F -t mangle
ExecStartPre=/sbin/iptables -X -t mangle
ExecStart=/usr/bin/dockerd
ExecStartPost=/sbin/iptables -P INPUT ACCEPT
ExecStartPost=/sbin/iptables -P OUTPUT ACCEPT
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

  # configuration for dockerd
  mkdir -p /etc/docker

  if [[ $(arch) == x86_64 ]]; then
  DOCKER_VER_MAIN=$(echo "$DOCKER_VER"|cut -d. -f1)
  CGROUP_DRIVER="cgroupfs"
  ((DOCKER_VER_MAIN>=20)) && CGROUP_DRIVER="systemd"
  clog debug "generate docker config: /etc/docker/daemon.json"
  if [[ "$ZONE" == cn ]];then
    clog debug "prepare register mirror for $ZONE"
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=$CGROUP_DRIVER"],
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  else
    clog debug "standard config without registry mirrors"
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=$CGROUP_DRIVER"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  fi
  else
  if [[ "$ZONE" == cn ]];then
    clog debug "prepare register mirror for $ZONE"
    cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  else
    clog debug "standard config without registry mirrors"
    cat > /etc/docker/daemon.json << EOF
{
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  fi
  fi

  # start docker service
  if [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
    clog debug "turn off selinux in CentOS/Redhat"
    getenforce|grep Disabled || setenforce 0
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
  fi

  clog debug "enable and start docker"
  systemctl enable docker
  systemctl daemon-reload && systemctl restart docker && sleep 4
}

function k8s_bin_get() {
  [[ (-f "/usr/local/bin/kubelet") && (-f "/usr/local/bin/kubeadm") && (-f "/usr/local/bin/kubectl") && (-f "/usr/local/bin/crictl") ]] && { clog warn "kubernetes binaries existed"; return 0; }

  os_arch="amd64"
  if [[ $(arch) == aarch64 ]]; then
      os_arch="arm64"
  fi

  CNI_VERSION="v0.8.2"
  DOWNLOAD_DIR=/usr/local/bin
  CRICTL_VERSION="v1.17.0"
  RELEASE=v${KUBERNETES_VERSION}
  RELEASE_VERSION="v0.4.0"

  mkdir -p /opt/cni/bin
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

  clog debug "get cni plugin"
  tar -zxvf ${BASE}/packages/containernetworking/${CNI_VERSION}/cni-plugins-linux-${os_arch}-${CNI_VERSION}.tgz -C /opt/cni/bin > /dev/null

  clog debug "get crictl"
  tar -zxvf ${BASE}/packages/cri-tools/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${os_arch}.tar.gz -C $DOWNLOAD_DIR > /dev/null

  clog debug "get kubeadm,kubelet,kubectl"
  mv ${BASE}/packages/kubernetes/${RELEASE}/bin/linux/${os_arch}/kubeadm $DOWNLOAD_DIR
  mv ${BASE}/packages/kubernetes/${RELEASE}/bin/linux/${os_arch}/kubelet $DOWNLOAD_DIR
  mv ${BASE}/packages/kubernetes/${RELEASE}/bin/linux/${os_arch}/kubectl $DOWNLOAD_DIR
  chmod +x {$DOWNLOAD_DIR/kubeadm,$DOWNLOAD_DIR/kubelet,$DOWNLOAD_DIR/kubectl}

  clog debug "config for kubelet service"
  cat ${BASE}/packages/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
  cat ${BASE}/packages/githubusercontent/kubernetes/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
}

function k8s_bin_download() {
  clog info "downloading kubernetes: ${KUBERNETES_VERSION} binaries"

  clog debug "downloading cni plugin"

#  curl -L "https://gitee.com/kubecube/packages/raw/master/containernetworking/${CNI_VERSION}/cni-plugins-linux-${os_arch}-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz
  curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${os_arch}-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

  clog debug "downloading crictl"
#  curl -L "https://gitee.com/kubecube/packages/raw/master/cri-tools/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${os_arch}.tar.gz" | tar -C $DOWNLOAD_DIR -xz
  curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${os_arch}.tar.gz" | tar -C $DOWNLOAD_DIR -xz

  clog debug "downloading kubeadm,kubelet,kubectl"
  RELEASE=v${KUBERNETES_VERSION}
  cd $DOWNLOAD_DIR
  curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${os_arch}/{kubeadm,kubelet,kubectl}
  chmod +x {kubeadm,kubelet,kubectl}

  clog debug "config for kubelet service"
  RELEASE_VERSION="v0.4.0"
  curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
  curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
}

function images_download() {
    clog info "downloading images"

    /usr/local/bin/kubeadm config images list >> /etc/kubecube/manifests/images.list

#    spin & spinpid=$!
#    echo
#    clog debug "spin pid: ${spinpid}"
#    trap 'kill ${spinpid} && exit 1' SIGINT
    for image in $(cat /etc/kubecube/manifests/images.list)
    do
      if [[ "$ZONE" == cn ]];then
        if [[ ${image} =~ ${K8S_REGISTR} ]]; then
          image=${image/$K8S_REGISTR/$CN_K8S_REGISTR}
        fi
      fi
      /usr/bin/docker pull ${image}
    done
#    kill "$spinpid" > /dev/null
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
apiServer:
  extraArgs:
    authentication-token-webhook-config-file: "/etc/cube/warden/webhook.config"
    audit-policy-file: "/etc/cube/audit/audit-policy.yaml"
    audit-webhook-config-file: "/etc/cube/audit/audit-webhook.config"
    audit-log-path: "/var/log/audit"
    audit-log-maxage: "10"
    audit-log-maxsize: "100"
    audit-log-maxbackup: "10"
    audit-log-format: "json"
  extraVolumes:
  - name: "cube"
    hostPath: "/etc/cube"
    mountPath: "/etc/cube"
    readOnly: true
    pathType: DirectoryOrCreate
  - name: audit-log
    hostPath: "/var/log/audit"
    mountPath: "/var/log/audit"
    readOnly: false
    pathType: DirectoryOrCreate
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
    TOKEN=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "kubeadm token create --ttl=10m")
    Hash=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
    if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
        CertificateKey=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
    fi
  elif [ ! -z ${ACCESS_PRIVATE_KEY_PATH} ]; then
    TOKEN=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" root@${MASTER_IP} "kubeadm token create --ttl=10m")
    Hash=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" root@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
    if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
        CertificateKey=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} root@${MASTER_IP} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
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
      sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "kubectl label nodes $(hostname) node-role.kubernetes.io/node="
    else
      ssh -i ${ACCESS_PRIVATE_KEY_PATH} -o "StrictHostKeyChecking no" root@${MASTER_IP} "kubectl label nodes $(hostname) node-role.kubernetes.io/node="
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
  offline_pkg_download
  docker_bin_get
  k8s_bin_get
  install_docker
  images_download
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