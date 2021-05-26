#!/bin/bash

set -e

# kubectl taint node master node-role.kubernetes.io/master-
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy metrics-server...\033[0m"
kubectl apply -f manifests/metrics-server/metrics-server.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy hnc-manager...\033[0m"
kubectl apply -f manifests/hnc/hnc.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing helm...\033[0m"
tar -zxvf manifests/helm/helm-v3.5.4-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>>	deploy nginx ingress controller...\033[0m"
#helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#helm repo update
#helm install ingress-nginx ingress-nginx/ingress-nginx

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	third dependence install success\033[0m"

