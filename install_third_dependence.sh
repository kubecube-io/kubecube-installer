#!/usr/bin/env bash

# note: this script should be idempotent.
# just used in warden distribution mode.

function init_etcd_secret (){
  kubectl create namespace kubecube-monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic etcd-certs -n kubecube-monitoring --dry-run=client -o yaml \
  --from-file=ca.crt=/etc/kubernetes/pki/ca.crt \
  --from-file=client.crt=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --from-file=client.key=/etc/kubernetes/pki/apiserver-etcd-client.key | kubectl apply -f -
}

if [ $(kubectl get nodes | wc -l) -eq 2 ]
then
  echo "[WARN]delete taint of master node while only one node found"
  kubectl get nodes | grep -v "NAME" | awk '{print $1}' | sed -n '1p' | xargs -t -i kubectl taint node {} node-role.kubernetes.io/master-
fi

NEED_INSTALL=$1
VERSION=$2

if [[ ${NEED_INSTALL} == "false" ]]; then
    exit 0
fi

if [ -z ${VERSION} ]; then
    VERSION=1.23
    echo "[INFO] use version ${VERSION}"
fi

echo "[INFO] deploying metrics-server"
helm install metrics-server /etc/kubecube/manifests/kubecube/${VERSION}/charts/metrics-server

echo "[INFO] deploying ingress-controller"
helm install ingress-controller /etc/kubecube/manifests/kubecube/${VERSION}/charts/ingress-controller

echo "[INFO] deploying local-path-storage"
helm install local-path-storage /etc/kubecube/manifests/kubecube/${VERSION}/charts/local-path-storage

echo "[INFO] deploying hnc"
helm install hnc /etc/kubecube/manifests/kubecube/${VERSION}/charts/hnc

echo "[INFO]third dependence install success"

