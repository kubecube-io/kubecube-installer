#!/bin/bash

IPADDR=$(hostname -I |awk '{print $1}')

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	download manifests for kubecube...\033[0m"
wget https://gitee.com/kubecube/manifests/repository/archive/master.zip
yum install -y unzip > /dev/null
unzip  master.zip

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	make configurations...\033[0m"
sudo sh manifests/make_config.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing kubernetes...\033[0m"
sudo sh manifests/install_kubernetes.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing third dependence...\033[0m"
sudo sh manifests/install_third_dependence.sh

# todo use hostname
cat >cluster.yaml <<EOF
apiVersion: cluster.kubecube.io/v1
kind: Cluster
metadata:
  name: member-cluster
spec:
  kubernetesAPIEndpoint: ${IPADDR}:6443
  networkType: calico
  isMemberCluster: false
  description: "this is member cluster"
  kubeconfig: ${cat /root/.kube/config | base64}
EOF

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	please execute 'kubectl apply -f cluster.yaml' in pivot cluster...\033[0m"