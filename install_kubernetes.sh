#!/bin/bash

source /etc/init.d/functions

SYS_VERSION=$(cat /etc/redhat-release)
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

if [ ${UID} -ne 0 ];then
  action "please use root to execute install shell..." /bin/false
  exit 1
fi

#if [ -z ${vip} ]
#then
#   echo "-z $a : 字符串长度为 0"
#else
#   echo "-z $a : 字符串长度不为 0"
#fi

function Kubernetes_Version (){
  echo -e "\033[32mVersion：1.20.0 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.9 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.8 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.6 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.5 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.4 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.3 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.2 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.1 Available...\033[0m"
  echo -e "\033[32mVersion：1.19.0 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.9 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.8 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.6 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.5 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.4 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.3 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.2 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.1 Available...\033[0m"
  echo -e "\033[32mVersion：1.18.0 Available...\033[0m"
}

function system_info () {
  echo -e "\033[32m-------------System Infomation-------------\033[0m"
  echo -e "\033[32m>>>>>>	System running time：${Uptime_day}${Uptime} \033[0m"
  echo -e "\033[32m>>>>>>	Operating system: ${SYS_VERSION} \033[0m"
  echo -e "\033[32m>>>>>>	IP: ${IPADDR} \033[0m"
  echo -e "\033[32m>>>>>>	CPU model:${CPU_Model} \033[0m"
  echo -e "\033[32m>>>>>>	CPU cores: ${CPU_NUM} \033[0m"
  echo -e "\033[32m>>>>>>	${DISK_INFO} \033[0m"
  echo -e "\033[32m>>>>>>	${DISK_Avail} \033[0m"
  echo -e "\033[32m>>>>>>	${MEM_INFO} \033[0m"
  echo -e "\033[32m>>>>>>	${MEM_Avail} \033[0m"
  echo -e "\033[32m>>>>>>	${LOAD_INFO} \033[0m"
}

function make_cluster_configuration () {
mkdir -p /etc/cube/kubeadm
cat >/etc/cube/kubeadm/init.config <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${Version}
#masterip和端口，这里也可以设置域名或者VIP
#controlPlaneEndpoint: ${IPADDR}
apiServer:
  extraArgs:
    advertise-address: ${IPADDR}
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
#  certSANs:
#  # 设置证书，如果是多个master就把master的ip和主机名写入，还可以配置域名和VIP
#  - ${IPADDR}
imageRepository: "hub.c.163.com/kubecube"
EOF
}

function Install_Kubernetes_Master (){
system_info
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Make ClusterConfiguration\033[0m"
make_cluster_configuration
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Installing Kubernetes, Version：${Version}\033[0m"
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Installing Kubernetes Master\033[0m"
echo -e "\033[32m================================================\033[0m"
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
echo -e "\033[32m>>>>>>	config hostname\033[0m"
hostnamectl set-hostname master

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config hosts\033[0m"
echo "master ${IPADDR}" >>/etc/hosts

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	closing swap\033[0m"
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config cornel params, passing bridge flow of IPv4 to iptables chain\033[0m"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
echo "1" > /proc/sys/net/ipv4/ip_forward

echo -e "\033[32m================================================\033[0m"
echo -e ">>>>>>	installing Docker-ce、config for auto start when start on\033[0m"
rpm -qa |grep docker |grep -v grep >/dev/null
if [ $? -ne 0 ];then
	yum -y install yum-utils device-mapper-persistent-data lvm2 >/dev/null
	yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	if [ ${Version} = "1.18.8" -o ${Version} = "1.19.0" ];then
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

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config source for docker registry\033[0m"
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://fl791z1h.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl daemon-reload
systemctl restart docker

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
yum -y install kubectl-${Version} kubelet-${Version} kubeadm-${Version} >/dev/null
rpm -qa |grep kubelet >/dev/null
if [ $? -eq 0 ];then
	systemctl enable kubelet
	systemctl start kubelet
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		action "kubelet-${Version} Start Success..." /bin/true
	else
		echo -e "\033[32m================================================\033[0m"
		action "kubelet-${Version} Start Failed..." /bin/false
		exit 1
	fi
else
	action "kubelet-${Version} Install Failed..." /bin/false
	exit 1
fi

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Init Kubernetes, Version${Version}\033[0m"
kubeadm init --config=/etc/cube/kubeadm/init.config -service-cidr=172.16.0.0/16 --pod-network-cidr=172.17.0.0/16
#kubeadm init --kubernetes-version=${Version} \
#--apiserver-advertise-address=${IPADDR} \
#--image-repository registry.aliyuncs.com/google_containers \
#--service-cidr=172.16.0.0/16 --pod-network-cidr=172.17.0.0/16

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

#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>> installing kubernetes-dashboard\033[0m"
#wget -q https://mirrors.yangxingzhen.com/kubernetes/recommended.yaml
#kubectl create -f recommended.yaml

#sleep 60 >/dev/null
#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>>	getting token\033[0m"
#kubectl -n kubernetes-dashboard get secret
#Token=$(kubectl -n kubernetes-dashboard get secret |awk '/kubernetes-dashboard-token/ {print $1}')

sleep 60 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect node\033[0m"
kubectl get node

sleep 60 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect pod\033[0m"
kubectl get pod --all-namespaces

sleep 60 >/dev/null
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	inspect service\033[0m"
kubectl get svc --all-namespaces

#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>>	crate rbac for kubernetes-dashboard\033[0m"
#kubectl create clusterrolebinding serviceaccount-cluster-admin --clusterrole=cluster-admin --user=system:serviceaccount:kubernetes-dashboard:kubernetes-dashboard

# wait for kubernetes-dashboard creating，predict completed time：4m40s(1.19.0)
#sleep 60 >/dev/null
echo -e "\033[32m==========================================================================\033[0m"
echo -e "\033[32m Kubernetes ${Version} deploy completed\033[0m"
#echo -e "\033[32m kubernetes-dashboard site https://${IPADDR}:30000\033[0m"
#echo -e "\033[32m Token get：kubectl describe secrets -n kubernetes-dashboard ${Token} |grep token |awk 'NR==3 {print \$2}'\033[0m"
echo -e "\033[32m==========================================================================\033[0m"
}

function Install_Kubernetes_Node (){
IPADDR=$(hostname -I |awk '{print $1}')
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Installing Kubernetes, Version：${Version}\033[0m"
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Installing Kubernetes Node\033[0m"
echo -e "\033[32m================================================\033[0m"
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
echo -e "\033[32m>>>>>>	config hostname\033[0m"
hostnamectl set-hostname node

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config hosts\033[0m"
echo "node ${IPADDR}" >>/etc/hosts

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	closing swap\033[0m"
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config cornel params, passing bridge flow of IPv4 to iptables chain\033[0m"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
echo "1" > /proc/sys/net/ipv4/ip_forward

echo -e "\033[32m================================================\033[0m"
echo -e ">>>>>>	installing Docker-ce、config for auto start when start on\033[0m"
rpm -qa |grep docker |grep -v grep >/dev/null
if [ $? -ne 0 ];then
	yum -y install yum-utils device-mapper-persistent-data lvm2 >/dev/null
	yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	if [ ${Version} = "1.18.8" -o ${Version} = "1.19.0" ];then
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

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config source for docker registry\033[0m"
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://fl791z1h.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl daemon-reload
systemctl restart docker

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	config source for kubernetes of yum\033[0m"
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
yum -y install kubectl-${Version} kubelet-${Version} kubeadm-${Version} >/dev/null
rpm -qa |grep kubelet >/dev/null
if [ $? -eq 0 ];then
	systemctl enable kubelet
	systemctl start kubelet
	if [ $? -eq 0 ];then
		echo -e "\033[32m================================================\033[0m"
		action "kubelet-${Version} Start Success..." /bin/true
	else
		echo -e "\033[32m================================================\033[0m"
		action "kubelet-${Version} Start Failed..." /bin/false
		exit 1
	fi
else
	action "kubelet-${Version} Install Failed..." /bin/false
	exit 1
fi

# join cluster
TOKEN=$(ssh root@${Master_IP} "kubeadm token list |grep token |awk '{print \$1}' |sed -n '1p'")
Hash=$(ssh root@${Master_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
kubeadm join ${Master_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${Hash}
}

function Main (){
stty erase '^H'
Code=""
while true
do
	read -p "$(echo -e "\033[32m Please enter the name of the node to be installed[master/node]：\033[0m")" Name
	if [ -z ${Name} ];then
		echo -e "\033[31m Input error, node name cannot be empty...\033[0m"
	elif [ ${Name} = "master" ];then
		while true
		do
			read -p "$(echo -e "\033[32m Please enter the Kubernetes version to be installed[Default：1.19.0], enter s/S to view the available versions：\033[0m")" Version
			if [ -z ${Version} ];then
				Version="1.19.0"
				Install_Kubernetes_Master
				Code="break"
			elif [ "${Version}" = "q" -o "${Version}" = "Q" ];then
				exit 1
			elif [ "${Version}" = "s" -o "${Version}" = "S" ];then
				Kubernetes_Version
			else
				Install_Kubernetes_Master
				Code="break"
			fi
		${Code}
		done
	elif [ ${Name} = "node" ];then
		while true
		do
			read -p "$(echo -e "\033[32m Please enter the Kubernetes version to be installed[Default：1.19.0], enter s/S to view the available versions：\033[0m")" Version
			if [ -z ${Version} ];then
				Version="1.19.0"
				Code="break"
			elif [ "${Version}" = "q" -o "${Version}" = "Q" ];then
				exit 1
			elif [ "${Version}" = "s" -o "${Version}" = "S" ];then
				Kubernetes_Version
			else
				while true
				do
					read -p "$(echo -e "\033[32m Please enter the IP of the Master node：\033[0m")" Master_IP
					if [ -z ${Master_IP} ];then
						echo -e "\033[31m Input error, Master node IP cannot be empty...\033[0m"
					else
						Install_Kubernetes_Node
						Code="break"
					fi
				${Code}
				done
			fi
		${Code}
		done
	else
		echo -e "\033[31m Input error, node name does not exist...\033[0m"
	fi
${Code}
done
}

Main