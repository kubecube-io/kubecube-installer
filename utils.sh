#!/usr/bin/env bash

IPADDR=$(hostname -I |awk '{print $1}')
Uptime_day=$(uptime |awk '{print $3,$4}')
CPU_NUM=$(grep -c 'processor' /proc/cpuinfo)
Uptime=$(uptime -p |awk '{print $6,$7,$8,$9}')
MEM_INFO=$(free -m |awk '/Mem/ {print "memory total:",$2"M"}')
CPU_Model=$(awk -F: '/name/ {print $NF}' /proc/cpuinfo |uniq)
CPU_ARCH=$(arch)
MEM_Avail=$(free -m |awk '/Mem/ {print "memory available:",$4"M"}')
DISK_INFO=$(df -h |grep -w "/" |awk '{print "disk total:",$1,$2}')
DISK_Avail=$(df -h |grep -w "/" |awk '{print "disk available:",$1,$4}')
LOAD_INFO=$(uptime |awk '{print "CPU load: "$(NF-2),$(NF-1),$NF}'|sed 's/\,//g')

# system_info inspect current machine
function system_info () {
  echo -e "\033[32m-------------System Infomation-------------\033[0m"
  echo -e "\033[32m System running time：${Uptime_day}${Uptime} \033[0m"
  echo -e "\033[32m IP: ${IPADDR} \033[0m"
  echo -e "\033[32m CPU model:${CPU_Model} \033[0m"
  echo -e "\033[32m CPU arch:${CPU_ARCH}  \033[0m"
  echo -e "\033[32m CPU cores: ${CPU_NUM} \033[0m"
  echo -e "\033[32m ${DISK_INFO} \033[0m"
  echo -e "\033[32m ${DISK_Avail} \033[0m"
  echo -e "\033[32m ${MEM_INFO} \033[0m"
  echo -e "\033[32m ${MEM_Avail} \033[0m"
  echo -e "\033[32m ${LOAD_INFO} \033[0m"
  echo -e "\033[32m--------------------------------------------\033[0m"
}

# clog print log with timestamp and custom level
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

# init_etcd_secret create etcd secret for monitoring at first
function init_etcd_secret (){
  kubectl create namespace kubecube-monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic etcd-certs -n kubecube-monitoring --dry-run=client -o yaml \
  --from-file=ca.crt=/etc/kubernetes/pki/ca.crt \
  --from-file=client.crt=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --from-file=client.key=/etc/kubernetes/pki/apiserver-etcd-client.key | kubectl apply -f -
}

# spin do wait print for circle
function spin() {
  sp='/-\|'
  printf ' '
  sleep 0.5
  while true; do
    printf '\b%.1s' "$sp"
    sp=${sp#?}${sp%???}
    sleep 0.5
  done
}

# cmd_must_exist check whether command is installed.
function cmd_must_exist {
    local CMD=$(command -v ${1})
    if [[ ! -x ${CMD} ]]; then
      echo "please install ${1} and verify they are in \$PATH."
      exit 1
    fi
}

# wait_pod_ready waits for pod state becomes ready until timeout.
# Parmeters:
#  - $1: pod label, such as "app=etcd"
#  - $2: pod namespace, such as "karmada-system"
#  - $3: time out, such as "200s"
function wait_pod_ready() {
    local pod_label=$1
    local pod_namespace=$2
    local wait_timeout=$3

    echo "wait the $pod_label ready..."
    set +e
    util::kubectl_with_retry wait --for=condition=Ready --timeout=30s pods -l app=${pod_label} -n ${pod_namespace}
    ret=$?
    set -e
    if [ $ret -ne 0 ];then
      echo "kubectl describe info:"
      kubectl describe pod -l app=${pod_label} -n ${pod_namespace}
    fi
    return ${ret}
}

# kubectl_with_retry will retry if execute kubectl command failed
# tolerate kubectl command failure that may happen before the pod is created by  StatefulSet/Deployment.
# default retry 10 times
function kubectl_with_retry() {
    local ret=0
    for i in {1..10}; do
        kubectl "$@"
        ret=$?
        if [[ ${ret} -ne 0 ]]; then
            echo "kubectl $@ failed, retrying(${i} times)"
            sleep 1
            continue
        else
            return 0
        fi
    done

    echo "kubectl $@ failed"
    kubectl "$@"
    return ${ret}
}

function helm_download() {
  clog info "download helm bin"
  if [[ $(arch) == x86_64 ]]; then
    wget https://kubecube.nos-eastchina1.126.net/helm/helm-v3.5.4-linux-amd64.tar.gz -O helm.tar.gz
    tar -xzvf helm.tar.gz > /dev/null
    chmod +x linux-amd64/helm
    mv linux-amd64/helm /usr/local/bin/helm
  else
    wget https://kubecube.nos-eastchina1.126.net/helm/helm-v3.6.2-linux-arm64.tar.gz -O helm.tar.gz
    tar -xzvf helm.tar.gz > /dev/null
    chmod +x linux-arm64/helm
    mv linux-arm64/helm /usr/local/bin/helm
  fi
}

function sign_cert() {
  clog info "signing cert..."
  mkdir -p ca
  cd ca

  ns=$1
  extra_ip=$2

  clog debug "generate ca key and ca cert"
  openssl genrsa -out ca.key 2048 > /dev/null
  openssl req -x509 -new -nodes -key ca.key -subj "/CN=*.kubecube-system" -days 10000 -out ca.crt > /dev/null

  clog debug "generate tls key"
  openssl genrsa -out tls.key 2048 > /dev/null

  clog debug "make tls csr"
cat << EOF >csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = ch
ST = zj
L = hz
O = kubecube
CN = *.${ns}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.${ns}
DNS.2 = *.${ns}.svc
DNS.3 = *.${ns}.svc.cluster.local
IP.1 = 127.0.0.1
IP.2 = ${extra_ip}

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF
  openssl req -new -key tls.key -out tls.csr -config csr.conf

  clog debug "generate tls cert"
  openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 10000 -extensions v3_ext -extfile csr.conf
  cd ..
}