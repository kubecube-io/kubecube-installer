#!/bin/bash

#source /etc/init.d/functions
source ./manifests/params_process.sh

#SYS_VERSION=$(cat /etc/redhat-release)
IPADDR=$(hostname -I |awk '{print $1}')
Uptime_day=$(uptime |awk '{print $3,$4}')
CPU_NUM=$(grep -c 'processor' /proc/cpuinfo)
Uptime=$(uptime -p |awk '{print $6,$7,$8,$9}')
MEM_INFO=$(free -m |awk '/Mem/ {print "memory total:",$2"M"}')
CPU_Model=$(awk -F: '/name/ {print $NF}' /proc/cpuinfo |uniq)
MEM_Avail=$(free -m |awk '/Mem/ {print "memory available:",$4"M"}')
DISK_INFO=$(df -h |grep -w "/" |awk '{print "disk total:",$1,$2}')
DISK_Avail=$(df -h |grep -w "/" |awk '{print "disk available:",$1,$4}')
LOAD_INFO=$(uptime |awk '{print "CPU load: "$(NF-2),$(NF-1),$NF}'|sed 's/\,//g')

function system_info () {
  echo -e "\033[32m-------------System Infomation-------------\033[0m"
  echo -e "\033[32m>>>>>>	System running time：${Uptime_day}${Uptime} \033[0m"
#  echo -e "\033[32m>>>>>>	Operating system: ${SYS_VERSION} \033[0m"
  echo -e "\033[32m>>>>>>	IP: ${IPADDR} \033[0m"
  echo -e "\033[32m>>>>>>	CPU model:${CPU_Model} \033[0m"
  echo -e "\033[32m>>>>>>	CPU cores: ${CPU_NUM} \033[0m"
  echo -e "\033[32m>>>>>>	${DISK_INFO} \033[0m"
  echo -e "\033[32m>>>>>>	${DISK_Avail} \033[0m"
  echo -e "\033[32m>>>>>>	${MEM_INFO} \033[0m"
  echo -e "\033[32m>>>>>>	${MEM_Avail} \033[0m"
  echo -e "\033[32m>>>>>>	${LOAD_INFO} \033[0m"
}

function prev_install_redhat() {
if [ ${ZONE} = "ch" ]; then
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Start previous requirements install... \033[0m"
echo -e "\033[32m>>>>>>	Config source of yum\033[0m"
mkdir -p /etc/yum.repos.d/bak
\mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak
[ -f $(which wget) ] || yum -y install wget >/dev/null
wget -q -P /etc/yum.repos.d http://mirrors.163.com/.help/CentOS7-Base-163.repo
yum clean all >/dev/null
yum makecache >/dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	yum updating...\033[0m"
yum -y update

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	install sshpass...\033[0m"
yum -y install sshpass >/dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	close firewall、selinux\033[0m"
SYSTEM_VERSION=$(awk -F. '{print $1}' /etc/redhat-release |awk '{print $NF}')
if [ ${SYSTEM_VERSION} -eq 6 ];then
	service iptables stop
	chkconfig iptables off
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	setenforce 0 >/dev/null
else
	systemctl stop firewalld.service
	systemctl disable firewalld.service
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	setenforce 0 >/dev/null
fi

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	closing swap\033[0m"
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config kernel params, passing bridge flow of IPv4 to iptables chain\033[0m"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
echo "1" > /proc/sys/net/ipv4/ip_forward

rpm -qa |grep docker |grep -v grep >/dev/null
if [ $? -ne 0 ];then
  echo -e "\033[32m================================================\033[0m"
  echo -e ">>>>>>	installing Docker-ce、config for auto start when start on\033[0m"
	yum -y install yum-utils device-mapper-persistent-data lvm2 >/dev/null
	yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo # todo 国内外源
	if [ ${KUBERNETES_VERSION} = "1.18.8" -o ${KUBERNETES_VERSION} = "1.19.0" ];then
		version="19.03.12"
	else
		version="18.09.9"
	fi
	yum -y install docker-ce-${version} docker-ce-cli-${version} containerd.io >/dev/null
	systemctl enable docker
	systemctl start docker
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m>>>>>>	Docker Start Success...\033[0m"
	else
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m>>>>>>	Docker Start Failed...\033[0m"
		exit 1
	fi
else
	echo -e "\033[32m================================================\033[0m"
	echo -e "\033[32m>>>>>>	Docker Version：$(docker --version |awk -F ',' '{print $1}') \033[0m"
fi

#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>>	config source for docker registry\033[0m"
#mkdir -p /etc/docker
#cat >/etc/docker/daemon.json <<EOF
#{
#  "registry-mirrors": ["https://fl791z1h.mirror.aliyuncs.com"],
#  "exec-opts": ["native.cgroupdriver=systemd"]
#}
#EOF
#systemctl daemon-reload
#systemctl restart docker

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>> config source for kubernetes of yum\033[0m"
cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing kubectl、kubelet、kubeadm\033[0m"
yum -y install kubectl-${KUBERNETES_VERSION} kubelet-${KUBERNETES_VERSION} kubeadm-${KUBERNETES_VERSION} >/dev/null
rpm -qa |grep kubelet >/dev/null
if [ $? -eq 0 ];then
	systemctl enable kubelet
	systemctl start kubelet
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Start Success...\033[0m"
	else
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Start Failed...\033[0m"
		exit 1
	fi
else
  echo -e "\033[32m================================================\033[0m"
	echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Install Failed...\033[0m"
	exit 1
fi
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	current only support ch! \033[0m"
  exit 1
fi
}

function prev_install_debian() {
if [ ${ZONE} = "ch" ]; then
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	apt-get updating...\033[0m"
apt-get update -y

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing dependence...\033[0m"
apt-get install -y rpm apt-transport-https ca-certificates curl gnupg2 software-properties-common sshpass  >/dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	closing swap\033[0m"
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config kernel params, passing bridge flow of IPv4 to iptables chain\033[0m"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
echo "1" > /proc/sys/net/ipv4/ip_forward

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	add k8s GPG key \033[0m"
curl http://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config k8s source of apt \033[0m"
cat  << EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

if [ ! -z $(uname -a | grep -i 'debian' | awk '{print $1}') ]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	add docker GPG key \033[0m"
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | apt-key add -
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	add source for apt \033[0m"
  add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/debian $(lsb_release -cs) stable"
fi

if [ ! -z $(uname -a | grep -i 'ubuntu' | awk '{print $1}') ]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	add docker GPG key \033[0m"
  curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg |  apt-key add -
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	add source for apt \033[0m"
  add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
fi

apt-get update -y

rpm -qa |grep docker |grep -v grep >/dev/null
if [ $? -ne 0 ];then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	installing Docker-ce、config for auto start when start on\033[0m"
  apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null
  systemctl enable docker
	systemctl start docker
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m>>>>>>	Docker Start Success...\033[0m"
	else
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m>>>>>>	Docker Start Failed...\033[0m"
		exit 1
	fi
else
	echo -e "\033[32m================================================\033[0m"
	echo -e "\033[32m>>>>>>	Docker Version：$(docker --version |awk -F ',' '{print $1}') \033[0m"
fi

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing kubectl、kubelet、kubeadm\033[0m"
apt-get install -y kubeadm=${KUBERNETES_VERSION}-00 kubectl=${KUBERNETES_VERSION}-00 kubelet=${KUBERNETES_VERSION}-00

rpm -qa |grep kubelet >/dev/null
if [ $? -eq 0 ];then
	systemctl enable kubelet
	systemctl start kubelet
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Start Success...\033[0m"
	else
		echo -e "\033[32m================================================\033[0m"
		echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Start Failed...\033[0m"
		exit 1
	fi
else
  echo -e "\033[32m================================================\033[0m"
	echo -e "\033[32m kubelet-${KUBERNETES_VERSION} Install Failed...\033[0m"
	exit 1
fi
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	current only support ch! \033[0m"
  exit 1
fi
}

function make_cluster_configuration (){
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Make ClusterConfiguration For Kubeadm\033[0m"
mkdir -p /etc/cube/kubeadm

if [ -z ${CONTROL_PLANE_ENDPOINT} ]
then
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m VIP not be set, use single master mode \033[0m"
cat >/etc/cube/kubeadm/init.config <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION}
apiServer:
  extraArgs:
    advertise-address: ${LOCAL_IP}
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
imageRepository: "hub.c.163.com/kubecube"
EOF
else
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m VIP is set: ${CONTROL_PLANE_ENDPOINT}, use control plane mode \033[0m"
cat >/etc/cube/kubeadm/init.config <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION}
#masterip和端口，这里也可以设置域名或者VIP
controlPlaneEndpoint: ${CONTROL_PLANE_ENDPOINT}
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
imageRepository: "hub.c.163.com/kubecube"
EOF
fi
}

function Install_Kubernetes_Master (){
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Init Kubernetes, Version${KUBERNETES_VERSION}\033[0m"
if [ ${NODE_MODE} = "master" ];then
kubeadm init --config=/etc/cube/kubeadm/init.config
elif [ ${NODE_MODE} = "control-plane-master" ];then
kubeadm init --config=/etc/cube/kubeadm/init.config --upload-certs
fi

mkdir -p ${HOME}/.kube
sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config kubectl autocomplete\033[0m"
rpm -qa |grep bash-completion >/dev/null
if [ $? -ne 0 ];then
	yum -y install bash-completion >/dev/null
	source /etc/profile.d/bash_completion.sh
fi

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing calico\033[0m"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

sleep 20 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect node\033[0m"
kubectl get node

sleep 20 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect pod\033[0m"
kubectl get pod --all-namespaces

sleep 20 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect service\033[0m"
kubectl get svc --all-namespaces

echo -e "\033[32m==========================================================================\033[0m"
echo -e "\033[32m Kubernetes ${KUBERNETES_VERSION} deploy completed\033[0m"
echo -e "\033[32m==========================================================================\033[0m"
}

function Install_Kubernetes_Node (){
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Init Kubernetes, Version：${KUBERNETES_VERSION}\033[0m"
echo -e "\033[32m================================================\033[0m"

if [ ! -z ${ACCESS_PASSWORD} ]; then
  echo 1
  TOKEN=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "kubeadm token list |grep token |awk '{print \$1}' |sed -n '1p'")
  Hash=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
  if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
      CertificateKey=$(sshpass -p ${ACCESS_PASSWORD} ssh -p 22 root@${MASTER_IP} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
  fi
elif [ ! -z ${ACCESS_PRIVATE_KEY_PATH} ]; then
  echo 2
  TOKEN=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} root@${MASTER_IP} "kubeadm token list |grep token |awk '{print \$1}' |sed -n '1p'")
  Hash=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} root@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
  if [ ! -z ${CONTROL_PLANE_ENDPOINT} ]; then
      CertificateKey=$(ssh -i ${ACCESS_PRIVATE_KEY_PATH} root@${MASTER_IP} "kubeadm init phase upload-certs --upload-certs | awk 'END {print}'")
  fi
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	ACCESS_PASSWORD or ACCESS_PRIVATE_KEY_PATH must be specified\033[0m"
fi

if [ ${NODE_MODE} = "node-join-control-plane" ]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	to join cluster as master \033[0m"
  kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${Hash} --control-plane --certificate-key ${CertificateKey}
elif [ ${NODE_MODE} = "node-join-master" ]; then
  kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${Hash}
fi
}

function Main() {
  system_info
  make_cluster_configuration
  prev_install

  has_apt=$(which apt)
  if [ ! -z ${has_apt} ]; then
      echo -e "\033[32m================================================\033[0m"
      echo -e "\033[32m>>>>>>	Installing on debian like os... \033[0m"
      prev_install_debian
  fi

  has_yum=$(which yum)
  if [ $? -eq 0 ]; then
      echo -e "\033[32m================================================\033[0m"
      echo -e "\033[32m>>>>>>	Installing on redhat like os... \033[0m"
      prev_install_redhat
  fi

  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	Installing Node MODE: ${NODE_MODE} \033[0m"

  if [ ${NODE_MODE} = "master" -o ${NODE_MODE} = "control-plane-master" ];then
    Install_Kubernetes_Master
  elif [ ${NODE_MODE} = "node-join-control-plane" -o ${NODE_MODE} = "node-join-master" ]; then
    Install_Kubernetes_Node
  fi
}

Main