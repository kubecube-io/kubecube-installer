#!/bin/bash

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Processing params... \033[0m"
source ./manifests/params_process.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Make Configurations for k8s api-server...\033[0m"
source ./manifests/make_config.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Copy third part helm charts to /etc/cube/helm-pkg \033[0m"
cp -r ./manifests/third-charts /etc/cube/helm-pkg

if [[ ${INSTALL_KUBERNETES} = "true" ]]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m Installing Kubernetes...\033[0m"
  /bin/bash ./manifests/install_k8s.sh
  if [ "$?" -ne 0 ]; then
      echo -e "\033[32m================================================\033[0m"
      echo -e "\033[32m [ERROR] Install Kubernetes Failed \033[0m"
      exit 1
  fi
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m IMPORTANT !!! ...                                 \033[0m"
  echo -e "\033[32m you need change the args of k8s api-server before \033[0m"
  echo -e "\033[32m installing kubecube, steps below:                 \033[0m"
  echo -e "\033[32m 1. find the manifests folder contains kube-apiserver.yaml   \033[0m"
  echo -e "\033[32m    generally in /etc/kubernetes/manifests of master node.   \033[0m"
  echo -e "\033[32m 2. add patches as below:   \033[0m"
  echo -e "\033[32m	spec:   \033[0m"
  echo -e "\033[32m	  containers:  \033[0m"
  echo -e "\033[32m	    - command:  \033[0m"
  echo -e "\033[32m	        - kube-apiserver  \033[0m"
  echo -e "\033[32m	        - --audit-webhook-config-file=/etc/cube/audit/audit-webhook.config  \033[0m"
  echo -e "\033[32m	        - --authentication-token-webhook-config-file=/etc/cube/warden/webhook.config  \033[0m"
  # todo: to complete it
  echo -e "\033[32m================================================\033[0m"

  echo -e "\033[32m Please enter 'exit' to modify args of k8s api-server \033[0m"
  echo -e "\033[32m After modify is done, please enter 'confirm' to continue \033[0m"
  while read confirm
  do
    if [[ ${confirm} = "confirm" ]]; then
      break
    elif [[ ${confirm} = "exit" ]]; then
      exit 1
    else
      continue
    fi
  done
fi

if [[ ${INSTALL_KUBECUBE_PIVOT} = "true" ]]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m>>>>>>	Installing Third Dependence...\033[0m"
  /bin/bash ./manifests/install_third_dependence.sh
  if [ "$?" -ne 0 ]; then
      echo -e "\033[32m================================================\033[0m"
      echo -e "\033[32m [ERROR] Install Third Dependence Failed \033[0m"
      exit 1
  fi

  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m	Installing KubeCube...\033[0m"
  /bin/bash ./manifests/install_kubecube.sh
  if [ "$?" -ne 0 ]; then
      echo -e "\033[32m================================================\033[0m"
      echo -e "\033[32m [ERROR] Install KubeCube Failed \033[0m"
      exit 1
  fi
fi

if [[ ${INSTALL_KUBECUBE_MEMBER} = "true" ]]; then
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m	Installing Third Dependence...\033[0m"
/bin/bash ./manifests/install_third_dependence.sh
if [ "$?" -ne 0 ]; then
    echo -e "\033[32m================================================\033[0m"
    echo -e "\033[32m [ERROR] Install Third Dependence Failed \033[0m"
    exit 1
fi

cat >cluster.yaml <<EOF
apiVersion: cluster.kubecube.io/v1
kind: Cluster
metadata:
  name: ${MEMBER_CLUSTER_NAME}
spec:
  kubernetesAPIEndpoint: ${LOCAL_IP}:6443
  networkType: calico
  isMemberCluster: true
  description: "this is member cluster"
  kubeconfig: $(cat /root/.kube/config | base64 -w 0)
EOF

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Member cluster is ready! \033[0m"
echo -e "\033[32m	Please execute 'kubectl apply -f cluster.yaml' in pivot cluster.\033[0m"
fi


