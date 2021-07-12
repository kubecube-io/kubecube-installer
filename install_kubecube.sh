#!/bin/bash

source /etc/kubecube/manifests/cube.conf
source /etc/kubecube/manifests/utils.sh

function sign_cert() {
  clog info "signing cert for kubecube"
  mkdir -p ca
  cd ca

  clog debug "generate ca key and ca cert"
  openssl genrsa -out ca.key 2048
  openssl req -x509 -new -nodes -key ca.key -subj "/CN=*.kubecube-system" -days 10000 -out ca.crt

  clog debug "generate tls key"
  openssl genrsa -out tls.key 2048

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
CN = *.kubecube-system

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.kubecube-system
DNS.2 = *.kubecube-system.svc
DNS.3 = *.kubecube-system.svc.cluster.local
IP.1 = 127.0.0.1
IP.2 = ${IPADDR}

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

function render_values() {
  clog info "render values for kubecube helm chart"
cat >values.yaml <<EOF
kubecube:
  replicas: ${kubecube_replicas}
  args:
    logLevel: ${kubecube_args_logLevel}
  env:
    pivotCubeHost: ${IPADDR}:30443

webhook:
  caBundle: $(cat ca/ca.crt | base64 -w 0)

tlsSecret:
  key: $(cat ca/tls.key | base64 -w 0)
  crt: $(cat ca/tls.crt | base64 -w 0)

caSecret:
  key: $(cat ca/ca.key | base64 -w 0)
  crt: $(cat ca/ca.crt | base64 -w 0)

pivotCluster:
  kubernetesAPIEndpoint: ${IPADDR}:6443
  kubeconfig: $(cat /root/.kube/config | base64 -w 0)
EOF
}

function make_hotplug() {
  clog info "render hotplug value"
cat >/etc/kubecube/manifests/previous/hotplug.yaml <<EOF
apiVersion: hotplug.kubecube.io/v1
kind: Hotplug
metadata:
  annotations:
    kubecube.io/sync: "true"
  name: common
spec:
  component:
    - name: audit
      status: disabled
    - name: logseer
      namespace: logseer
      pkgName: logseer-v1.0.0.tgz
      status: disabled
    - env: |
        clustername: "{{.cluster}}"
      name: logagent
      namespace: logagent
      pkgName: logagent-v1.0.0.tgz
      status: disabled
    - env: |
        grafana:
          enabled: false
        prometheus:
          prometheusSpec:
            externalLabels:
              cluster: "{{.cluster}}"
            remoteWrite:
            - url: http://${IPADDR}:31291/api/v1/receive
      name: kubecube-monitoring
      namespace: kubecube-monitoring
      pkgName: kubecube-monitoring-15.4.8.tgz
      status: enabled
    - name: thanos
      namespace: kubecube-monitoring
      pkgName: thanos-3.18.0.tgz
      status: disabled
---
apiVersion: hotplug.kubecube.io/v1
kind: Hotplug
metadata:
  annotations:
    kubecube.io/sync: "true"
  name: pivot-cluster
spec:
  component:
    - name: logseer
      status: disabled
    - env: |
        grafana:
          enabled: true
        prometheus:
          prometheusSpec:
            externalLabels:
              cluster: "{{.cluster}}"
            remoteWrite:
            - url: http://kubecube-thanos-receive:19291/api/v1/receive
      name: kubecube-monitoring
    - env: |
        receive:
          replicaCount: 1
          replicationFactor: 1
      name: kubecube-thanos
      status: enabled
EOF
}

make_hotplug
sign_cert
render_values

clog debug "create previous for kubecube"
kubectl apply -f /etc/kubecube/manifests/previous/previous.yaml

clog info "deploy frontend for kubecube"
kubectl apply -f /etc/kubecube/manifests/frontend/frontend.yaml

clog info "deploy audit server for kubecube"
kubectl apply -f /etc/kubecube/manifests/audit/audit.yaml

clog info "deploy webconsole and cloudshell"
kubectl apply -f /etc/kubecube/manifests/webconsole/webconsole.yaml

clog info "deploy kubecube"
/usr/local/bin/helm install -f values.yaml kubecube /etc/kubecube/manifests/kubecube/v0.0.1

clog info "waiting for kubecube ready"
spin & spinpid=$!
clog debug "spin pid: ${spinpid}"
trap 'kill ${spinpid} && exit 1' SIGINT
while true
do
  cube_healthz=$(curl -s http://${IPADDR}:30007/healthz)
  warden_healthz=$(curl -s -k https://${IPADDR}:31443/healthz)
  if [[ ${cube_healthz} = "healthy" && ${warden_healthz} = "healthy" ]]; then
    echo
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m               Welcome to KubeCube!                   \033[0m"
    echo -e "\033[32m         Please use 'admin/admin123' to access        \033[0m"
    echo -e "\033[32m                '${IPADDR}:30080'                     \033[0m"
    echo -e "\033[32m         You must change password after login         \033[0m"
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m========================================================\033[0m"
    kill "$spinpid" > /dev/null
    exit 0
  fi
  sleep 7 > /dev/null
done

kubectl apply -f /etc/kubecube/manifests/previous/hotplug.yaml > /dev/null


