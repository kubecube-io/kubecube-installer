#!/bin/bash

if [ ${UID} -ne 0 ];then
  echo -e "\033[32m please use root to execute install shell\033[0m"
  exit 1
fi

mkdir -p /etc/kubecube
mkdir -p /etc/kubecube/down
mkdir -p /etc/kubecube/bin
cd /etc/kubecube

echo -e "$(date +'%Y-%m-%d %H:%M:%S') \033[32mINFO\033[0m downloading manifests for kubecube"
#wget https://gitee.com/kubecube/manifests/repository/archive/master.zip -O manifests.zip

source /etc/kubecube/manifests/utils.sh

system_info
env_check

#unzip manifests.zip > /dev/null

if [[ ${CUSTOMIZE} = "true" ]]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m Please make sure under kubecube folder         \033[0m"
  echo -e "\033[32m 'cd /etc/kubecube/manifests'                   \033[0m"
  echo -e "\033[32m Please modify install.conf                     \033[0m"
  echo -e "\033[32m 'vi install.conf'                              \033[0m"
  echo -e "\033[32m Please modify cube.conf                        \033[0m"
  echo -e "\033[32m 'vi cube.conf'                                 \033[0m"
  echo -e "\033[32m Confirm every args then do command below:      \033[0m"
  echo -e "\033[32m '/bin/bash install.sh'                         \033[0m"
  echo -e "\033[32m================================================\033[0m"
  exit 0
fi

/bin/bash /etc/kubecube/manifests/install.sh
