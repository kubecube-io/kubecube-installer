#!/bin/bash

set -e

function warden_webhook() {
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
}

function audit_webhook() {
cat >/etc/cube/audit/audit-webhook.config  <<EOF
apiVersion: v1
clusters:
- cluster:
    server: http://${IPADDR}:8888/api/v1/cube/audit/k8s
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
}

function audit_policy() {
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

function params_process() {
if [ -z ${NODE_MODE} ]
then
  echo -e "\033[31m NODE_MODE can not be empty! \033[0m"
  exit 1
else
  NODE_MODE_LEGAL="false"
  for v in "control-plane-master" "master" "node-join-control-planer" "node-join-master"
  do
    if [ ${NODE_MODE} = $v ];then
      NODE_MODE_LEGAL="true"
      break
    fi
  done
  if [ ${NODE_MODE_LEGAL} = "false" ]; then
    echo -e "\033[31m NODE_MODE illegal! must be one of: \033[0m"
    echo -e "\033[31m control-plane-master,master,node-join-control-planer,node-join-master \033[0m"
    exit 1
  fi
fi

if [ -z ${MASTER_IP} ]; then
  echo -e "\033[31m MASTER_IP can not be empty! \033[0m"
  exit 1
fi

if [ -z ${LOCAL_IP} ]; then
  echo -e "\033[31m empty LOCAL_IP, exact ip by default \033[0m"
  LOCAL_IP=$(hostname -I |awk '{print $1}')
fi

if [ -z ${MEMBER_CLUSTER_NAME} ]; then
  echo -e "\033[32m empty MEMBER_CLUSTER_NAME, used hostname by default \033[0m"
  MEMBER_CLUSTER_NAME = $(hostname)
fi

if [ -z ${ZONE} ]; then
  ZONE="ch"
fi
}

mkdir -p /etc/cube/warden
mkdir -p /etc/cube/audit

params_process
warden_webhook
audit_webhook
audit_policy

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	make configurations success\033[0m"

