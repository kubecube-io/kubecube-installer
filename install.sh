#!/usr/bin/env bash

source /etc/kubecube/manifests/utils.sh
source /etc/kubecube/manifests/install.conf

system_info

# params_process do params check of install.conf
function params_process() {
  # check NODE_MODE
  if [ -z ${NODE_MODE} ]
  then
    clog error "NODE_MODE can not be empty!"
    exit 1
  else
    NODE_MODE_LEGAL="false"
    for v in "control-plane-master" "master" "node-join-control-plane" "node-join-master"
    do
      if [ ${NODE_MODE} = $v ];then
        NODE_MODE_LEGAL="true"
        break
      fi
    done
    if [ ${NODE_MODE_LEGAL} = "false" ]; then
      clog error "NODE_MODE illegal! must be one of:control-plane-master,master,node-join-control-plane,node-join-master"
      exit 1
    fi
  fi

  # check CNI
  if [ -z ${CNI} ]; then
      clog error "CNI can not be empty"
      exit 1
  fi

  # check MASTER_IP
  if [ -z ${MASTER_IP} ]; then
    if [ ${NODE_MODE} = "master" ]; then
      MASTER_IP=$(hostname -I |awk '{print $1}')
    else
      clog error "MASTER_IP can not be empty!"
      exit 1
    fi
  fi

  # check ZONE
  if [ -z ${ZONE} ]; then
    ZONE="ch"
  fi

  if [ ! -z ${KUBERNETES_BIND_ADDRESS} ]; then
    IPADDR=${KUBERNETES_BIND_ADDRESS}
  fi
}

params_process

# install k8s or not
if [[ ${INSTALL_KUBERNETES} = "true" ]]; then
  /bin/bash /etc/kubecube/manifests/install_k8s.sh
  if [ "$?" -ne 0 ]; then
    clog error "install kubernetes failed"
      exit 1
  fi

  if [[ ${PRE_DOWNLOAD} = "true" ]]; then
    clog info "offline manifests download success"
    exit 0
  fi
fi

if [[ ${INSTALL_KUBECUBE_PIVOT} = "true" ]]; then
# download helm to install kubecube helm chart
helm_download
/bin/bash /etc/kubecube/manifests/install_kubecube.sh
fi
