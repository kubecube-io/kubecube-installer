#!/bin/bash

if [ $(kubectl get nodes | wc -l) -eq 2 ]
then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	delete taint of master node...\033[0m"
  kubectl get nodes | grep -v "NAME" | awk '{print $1}' | sed -n '1p' | xargs -t -i kubectl taint node {} node-role.kubernetes.io/master-
fi

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy hnc-manager...\033[0m"
kubectl apply -f manifests/hnc/hnc.yaml

sleep 60 >/dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy metrics-server...\033[0m"
kubectl apply -f manifests/metrics-server/metrics-server.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy nginx ingress controller...\033[0m"
kubectl apply -f manifests/ingress-controller/ingress-controller.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing helm...\033[0m"
tar -zxvf manifests/helm/helm-v3.5.4-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	third dependence install success\033[0m"

