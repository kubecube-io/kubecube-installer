#!/bin/bash

source ./manifests/install.conf

#echo -e "\033[32m================================================\033[0m"
#echo -e "\033[32m>>>>>>	download manifests for kubecube...\033[0m"
#wget https://gitee.com/kubecube/manifests/repository/archive/master.zip
#yum install -y unzip > /dev/null
#unzip  master.zip > /dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Make Configurations for k8s api-server...\033[0m"
source ./manifests/make_config.sh

# todo: to support different linux os
if [ ${INSTALL_KUBERNETES} = "true" ]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	Installing Kubernetes...\033[0m"
  sh ./manifests/install_k8s_on_centos.sh
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	IMPORTANT !!! ...                                 \033[0m"
  echo -e "\033[32m>>>>>>	you need change the args of k8s api-server before \033[0m"
  echo -e "\033[32m>>>>>>	installing kubecube, steps below:                 \033[0m"
  echo -e "\033[32m>>>>>>	1. find the manifests folder contains kube-apiserver.yaml   \033[0m"
  echo -e "\033[32m>>>>>>	   generally in /etc/kubernetes/manifests of master node.   \033[0m"
  echo -e "\033[32m>>>>>>	2. add patches as below:   \033[0m"
  echo -e "\033[32m>>>>>>	spec:   \033[0m"
  echo -e "\033[32m>>>>>>	  containers:  \033[0m"
  echo -e "\033[32m>>>>>>	    - command:  \033[0m"
  echo -e "\033[32m>>>>>>	        - kube-apiserver  \033[0m"
  echo -e "\033[32m>>>>>>	        - --audit-webhook-config-file=/etc/cube/audit/audit-webhook.config  \033[0m"
  echo -e "\033[32m>>>>>>	        - --authentication-token-webhook-config-file=/etc/cube/warden/webhook.config  \033[0m"
  # todo: need confirm
fi

if [ ${INSTALL_KUBECUBE_PIVOT} = "true" ]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	Installing Third Dependence...\033[0m"
  sh ./manifests/install_third_dependence.sh

  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	Installing KubeCube...\033[0m"
  sh ./manifests/install_kubecube.sh
fi

if [ ${INSTALL_KUBECUBE_MEMBER} = "true" ]; then
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Installing Third Dependence...\033[0m"
sh ./manifests/install_third_dependence.sh

cat >cluster.yaml <<EOF
apiVersion: cluster.kubecube.io/v1
kind: Cluster
metadata:
  name: ${MEMBER_CLUSTER_NAME}
spec:
  kubernetesAPIEndpoint: ${LOCAL_IP}:6443
  networkType: calico
  isMemberCluster: false
  description: "this is member cluster"
  kubeconfig: $(cat /root/.kube/config | base64 -w 0)
EOF

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>> member cluster is ready! \033[0m"
echo -e "\033[32m>>>>>>	please execute 'kubectl apply -f cluster.yaml' in pivot cluster.\033[0m"
fi


