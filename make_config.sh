#!/bin/bash

IPADDR=$(hostname -I |awk '{print $1}')

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

mkdir -p /etc/cube/warden
mkdir -p /etc/cube/audit

warden_webhook
audit_webhook
audit_policy

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	make configurations success\033[0m"

