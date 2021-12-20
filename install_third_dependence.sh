#!/usr/bin/env bash

# note: this script should be idempotent

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

echo "[INFO]deploy local-path-storage"
kubectl apply -f /etc/kubecube/manifests/local-path-storage/local-path-storage.yaml > /dev/null

echo "[INFO]deploy metrics-server"
kubectl apply -f /etc/kubecube/manifests/metrics-server/metrics-server.yaml > /dev/null

# nginx ingress controller doesn't support arm64
echo "[INFO]deploy nginx ingress controller"
kubectl apply -f /etc/kubecube/manifests/ingress-controller/ingress-controller.yaml > /dev/null

echo "[INFO]init etcd-certs secret for etcd monitoring"
init_etcd_secret

echo "[INFO]deploy hnc-manager, and wait for ready"
kubectl apply -f /etc/kubecube/manifests/hnc/hnc.yaml > /dev/null

hnc_ready="0/2"
while [ ${hnc_ready} != "2/2" ]
do
  sleep 5 > /dev/null
  hnc_ready=$(kubectl get pod -n hnc-system | awk '{print $2}' | sed -n '2p')
done
sleep 20 > /dev/null

echo "[INFO]third dependence install success"

