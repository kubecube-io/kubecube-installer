#!/bin/bash

source ./manifests/install.conf

function params_process() {
if [ -z ${NODE_MODE} ]
then
  echo -e "\033[32m NODE_MODE can not be empty! \033[0m"
  exit 1
else
  NODE_MODE_LEGAL="false"
  for v in "control-plane-master" "master" "node-join-control-planer" "node-join-master"
  do
    if [ ${NODE_MODE} = $v ];then
      NODE_MODE_LEGAL="true"
      break
    fi
  done
  if [ ${NODE_MODE_LEGAL} = "false" ]; then
    echo -e "\033[32m NODE_MODE illegal! must be one of: \033[0m"
    echo -e "\033[32m control-plane-master,master,node-join-control-planer,node-join-master \033[0m"
    exit 1
  fi
fi

if [ -z ${MASTER_IP} ]; then
  if [ ${NODE_MODE} = "master" ]; then
    MASTER_IP=$(hostname -I |awk '{print $1}')
  else
    echo -e "\033[32m MASTER_IP can not be empty! \033[0m"
    exit 1
  fi
fi

if [ -z ${LOCAL_IP} ]; then
  echo -e "\033[32m empty LOCAL_IP, exact ip by default \033[0m"
  LOCAL_IP=$(hostname -I |awk '{print $1}')
fi

#if [ -z ${MEMBER_CLUSTER_NAME} ]; then
#  echo -e "\033[32m empty MEMBER_CLUSTER_NAME, used hostname by default \033[0m"
#  MEMBER_CLUSTER_NAME = $(hostname)
#fi

if [ -z ${ZONE} ]; then
  ZONE="ch"
fi
}

params_process
