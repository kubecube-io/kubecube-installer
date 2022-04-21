#!/usr/bin/env bash

source /etc/kubecube/manifests/utils.sh

# todo: allow user customize
function render_values() {
  clog info "render values for kubecube chart values"
cat >> values.yaml <<EOF
global:
  certs:
    tls:
      key: "$(cat ca/tls.key | base64 -w 0)"
      crt: "$(cat ca/tls.crt | base64 -w 0)"
    ca:
      key: "$(cat ca/ca.key | base64 -w 0)"
      crt: "$(cat ca/ca.crt | base64 -w 0)"
kubecube:
  env:
    pivotCubeHost: "${IPADDR}:30443"
  pivotCluster:
    kubernetesAPIEndpoint: "${IPADDR}:6443"
    kubeconfig: "$(cat /root/.kube/config | base64 -w 0)"
EOF
}

# todo: move it to helm chart
function make_hotplug() {
  clog info "render hotplug value"
cat > hotplug.yaml <<EOF
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
    - name: elasticsearch
      namespace: elasticsearch
      pkgName: elasticsearch-7.8.1.tgz
      status: enabled
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
      pkgName: kubecube-monitoring-15.4.12.tgz
      status: enabled
    - name: kubecube-thanos
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
          tsdbRetention: 7d
          replicaCount: 1
          replicationFactor: 1
      name: kubecube-thanos
      status: enabled
EOF
}

# install monitor secret
/bin/bash /etc/kubecube/manifests/install_third_dependence.sh false

make_hotplug
sign_cert
render_values

clog info "deploy kubecube"
/usr/local/bin/helm install -f values.yaml kubecube /etc/kubecube/manifests/kubecube

clog info "waiting for kubecube ready..."
timeout=180
for ((time=0; time<${timeout}; time++)); do
  pivot_cluster_ready=$(kubectl get cluster pivot-cluster | awk '{print $2}' | sed -n '2p')
  if [[ ${pivot_cluster_ready} = "normal" ]]; then
    echo
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m               Welcome to KubeCube!                   \033[0m"
    echo -e "\033[32m         Please use 'admin/admin123' to access        \033[0m"
    echo -e "\033[32m                '${IPADDR}:30080'                     \033[0m"
    echo -e "\033[32m         You must change password after login         \033[0m"
    echo -e "\033[32m========================================================\033[0m"
    echo -e "\033[32m========================================================\033[0m"
    kubectl apply -f ./hotplug.yaml > /dev/null
    exit 0
  fi
  sleep 1
done

clog error "waiting for kubecube ready timeout"
exit 1

