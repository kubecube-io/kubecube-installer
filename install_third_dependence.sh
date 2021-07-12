#!/bin/bash

source /etc/kubecube/manifests/utils.sh

function init_etcd_secret (){
  kubectl create namespace kubecube-monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic etcd-certs -n kubecube-monitoring --dry-run=client -o yaml \
  --from-file=ca.crt=/etc/kubernetes/pki/ca.crt \
  --from-file=client.crt=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --from-file=client.key=/etc/kubernetes/pki/apiserver-etcd-client.key | kubectl apply -f -
}

if [ $(kubectl get nodes | wc -l) -eq 2 ]
then
  clog info "delete taint of master node while only one node found"
  kubectl get nodes | grep -v "NAME" | awk '{print $1}' | sed -n '1p' | xargs -t -i kubectl taint node {} node-role.kubernetes.io/master-
fi

clog info "deploy hnc-manager, and wait for ready"
kubectl apply -f /etc/kubecube/manifests/hnc/hnc.yaml > /dev/null

spin & spinpid=$!
clog debug "spin pid: ${spinpid}"
trap 'kill ${spinpid} && exit 1' SIGINT
hnc_ready="0/2"
while [ ${hnc_ready} != "2/2" ]
do
  sleep 5 > /dev/null
  hnc_ready=$(kubectl get pod -n hnc-system | awk '{print $2}' | sed -n '2p')
done
sleep 20 > /dev/null
kill "$spinpid" > /dev/null

clog info "deploy local-path-storage"
kubectl apply -f /etc/kubecube/manifests/local-path-storage/local-path-storage.yaml > /dev/null

clog info "deploy metrics-server"
kubectl apply -f /etc/kubecube/manifests/metrics-server/metrics-server.yaml > /dev/null

clog info "deploy nginx ingress controller"
kubectl apply -f /etc/kubecube/manifests/ingress-controller/ingress-controller.yaml /dev/null

clog info "init etcd-certs secret for etcd monitoring"
init_etcd_secret

clog info "installing helm"
if [[ $(arch) == x86_64 ]]; then
  tar -zxvf /etc/kubecube/manifests/helm/helm-v3.5.4-linux-amd64.tar.gz > /dev/null
  mv linux-amd64/helm /usr/local/bin/helm
else
  tar -zxvf /etc/kubecube/manifests/helm/helm-v3.6.2-linux-arm64.tar.gz > /dev/null
  mv linux-arm64/helm /usr/local/bin/helm
fi

clog info "third dependence install success"

