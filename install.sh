#!/usr/bin/env bash

source /etc/kubecube/manifests/utils.sh

system_info
params_process

# install k8s or not
if [[ ${INSTALL_KUBERNETES} = "true" ]]; then
  if [[ ${CONTAINER_RUNTIME} = "containerd" ]]; then
    /bin/bash /etc/kubecube/manifests/install_k8s_containerd.sh
  elif [[ ${CONTAINER_RUNTIME} = "docker" ]]; then
    /bin/bash /etc/kubecube/manifests/install_k8s.sh
  fi
  if [ "$?" -ne 0 ]; then
    clog error "install kubernetes failed"
      exit 1
  fi

  if [[ ${PRE_DOWNLOAD} = "true" ]]; then
    clog info "offline manifests download success"
    exit 0
  fi
fi

# install kubecube as pivot cluster
if [[ ${INSTALL_KUBECUBE_PIVOT} = "true" ]]; then
  /bin/bash /etc/kubecube/manifests/install_third_dependence.sh
  if [ "$?" -ne 0 ]; then
    clog error "install third dependence failed"
    exit 1
  fi

  /bin/bash /etc/kubecube/manifests/install_kubecube.sh
  if [ "$?" -ne 0 ]; then
      clog error "install kubecube failed"
      exit 1
  fi
fi

# add member cluster to pivot
if [[ ${INSTALL_KUBECUBE_MEMBER} = "true" ]]; then
# invoke cluster register api of kubecube
curl -s -k -H "Content-type: application/json" -X POST https://${KUBECUBE_HOST}:30443/api/v1/cube/clusters/register -d "{\"apiVersion\":\"cluster.kubecube.io/v1\",\"kind\":\"Cluster\",\"metadata\":{\"name\":\"${MEMBER_CLUSTER_NAME}\"},\"spec\":{\"kubernetesAPIEndpoint\":\"${LOCAL_IP}:6443\",\"networkType\":\"calico\",\"isMemberCluster\":true,\"description\":\"this is member cluster\",\"kubeconfig\":\"$(cat /root/.kube/config | base64 -w 0)\"}}" >/dev/null
if [[ $? = 0 ]]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m             add cluster success!               \033[0m"
  echo -e "\033[32m      please go to console and check out!       \033[0m"
  echo -e "\033[32m================================================\033[0m"
  exit 0
else
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m             add cluster failed.                \033[0m"
  echo -e "\033[32m================================================\033[0m"
  exit 1
fi
fi
