#!/usr/bin/env bash

source /etc/kubecube/manifests/install.conf

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

function params_process() {
  if [ -z ${NODE_MODE} ]
  then
    clog error "NODE_MODE can not be empty!"
    exit 1
  else
    NODE_MODE_LEGAL="false"
    for v in "control-plane-master" "master" "node-join-control-plane" "node-join-master"
    do
      if [ ${NODE_MODE} = $v ];then
        NODE_MODE_LEGAL="true"
        break
      fi
    done
    if [ ${NODE_MODE_LEGAL} = "false" ]; then
      clog error "NODE_MODE illegal! must be one of:control-plane-master,master,node-join-control-plane,node-join-master"
      exit 1
    fi
  fi

  if [ -z ${MASTER_IP} ]; then
    if [ ${NODE_MODE} = "master" ]; then
      MASTER_IP=$(hostname -I |awk '{print $1}')
    else
      clog error "MASTER_IP can not be empty!"
      exit 1
    fi
  fi

  if [ -z ${LOCAL_IP} ]; then
    LOCAL_IP=$(hostname -I |awk '{print $1}')
  fi

  #if [ -z ${MEMBER_CLUSTER_NAME} ]; then
  #  echo -e "\033[32m empty MEMBER_CLUSTER_NAME, used hostname by default \033[0m"
  #  MEMBER_CLUSTER_NAME = $(hostname)
  #fi

  if [ -z ${ZONE} ]; then
    ZONE="ch"
  fi
}

function configs_for_apiserver() {
  clog info "make configs for k8s api-server"

  mkdir -p /etc/cube/warden
  mkdir -p /etc/cube/audit

cat >/etc/cube/warden/webhook.config <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: warden
    cluster:
      server: https://${IPADDR}:31443/api/v1/warden/authenticate
      insecure-skip-tls-verify: true
users:
  - name: api-server

current-context: webhook
contexts:
  - context:
      cluster: warden
      user: api-server
    name: webhook
EOF

cat >/etc/cube/audit/audit-webhook.config  <<EOF
apiVersion: v1
clusters:
- cluster:
    server: http://${IPADDR}:30008/api/v1/cube/audit/k8s
    insecure-skip-tls-verify: true
  name: audit
contexts:
- context:
    cluster: audit
    user: ""
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users: []
EOF

cat >/etc/cube/audit/audit-policy.yaml  <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "ResponseStarted"
  - "RequestReceived"
rules:
- level: None
  nonResourceURLs:
    - /apis*
    - /api/v1?timeout=*
    - /api?timeout=*
- level: Metadata
  userGroups: ["kubecube"]
EOF
}

function alert_modify_apiserver() {
  echo -e "\033[32m================================================================================================\033[0m"
  echo -e "\033[32m IMPORTANT !!!                                                                                  \033[0m"
  echo -e "\033[32m You must change the args of k8s api-server before installing kubecube, steps below:            \033[0m"
  echo -e "\033[32m 1. find the manifests folder contains kube-apiserver.yaml                                      \033[0m"
  echo -e "\033[32m    generally in /etc/kubernetes/manifests of master node.                                      \033[0m"
  echo -e "\033[32m 2. add patches as below:                                                                       \033[0m"
  echo -e "\033[32m================================================================================================\033[0m"
  echo -e "\033[32m spec:                                                                                          \033[0m"
  echo -e "\033[32m   containers:                                                                                  \033[0m"
  echo -e "\033[32m     - command:                                                                                 \033[0m"
  echo -e "\033[32m         - kube-apiserver                                                                       \033[0m"
  echo -e "\033[32m         - --audit-webhook-config-file=/etc/cube/audit/audit-webhook.config                     \033[0m"
  echo -e "\033[32m         - --audit-policy-file=/etc/cube/audit/audit-policy.yaml                                \033[0m"
  echo -e "\033[32m         - --authentication-token-webhook-config-file=/etc/cube/warden/webhook.config           \033[0m"
  echo -e "\033[32m         - --audit-log-format=json                                                              \033[0m"
  echo -e "\033[32m         - --audit-log-maxage=10                                                                \033[0m"
  echo -e "\033[32m         - --audit-log-maxbackup=10                                                             \033[0m"
  echo -e "\033[32m         - --audit-log-maxsize=100                                                              \033[0m"
  echo -e "\033[32m         - --audit-log-path=/var/log/audit.log                                                      \033[0m"
  echo -e "\033[32m       volumeMounts:                                                                            \033[0m"
  echo -e "\033[32m       - mountPath: /var/log/audit.log                                                              \033[0m"
  echo -e "\033[32m         name: audit-log                                                                        \033[0m"
  echo -e "\033[32m       - mountPath: /etc/cube                                                                   \033[0m"
  echo -e "\033[32m         name: cube                                                                             \033[0m"
  echo -e "\033[32m         readOnly: true                                                                         \033[0m"
  echo -e "\033[32m   volumes:                                                                                     \033[0m"
  echo -e "\033[32m     - hostPath:                                                                                 \033[0m"
  echo -e "\033[32m         path: /var/log/audit.log                                                                   \033[0m"
  echo -e "\033[32m         type: FileOrCreate                                                                \033[0m"
  echo -e "\033[32m       name: audit-log                                                                          \033[0m"
  echo -e "\033[32m     - hostPath:                                                                                 \033[0m"
  echo -e "\033[32m         path: /etc/cube                                                                        \033[0m"
  echo -e "\033[32m         type: DirectoryOrCreate                                                                \033[0m"
  echo -e "\033[32m       name: cube                                                                               \033[0m"
  echo -e "\033[32m================================================================================================\033[0m"
  echo -e "\033[32m Please enter 'exit' to modify args of k8s api-server \033[0m"
  echo -e "\033[32m After modify is done, please redo script and enter 'confirm' to continue \033[0m"
}

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