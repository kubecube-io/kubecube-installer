#!/bin/bash

if [ ${UID} -ne 0 ];then
  echo -e "\033[32m please use root to execute install shell...\033[0m"
  exit 1
fi

mkdir kubecube
cd kubecube

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Download manifests for kubecube...\033[0m"
echo -e "\033[32m================================================\033[0m"
wget https://gitee.com/kubecube/manifests/repository/archive/feature/master.zip

has_apt=$(which apt)
if [ ! -z ${has_apt} ]; then
  echo -e "\033[32m Update apt...\033[0m"
  echo -e "\033[32m================================================\033[0m"
  apt-get update -y
  apt-get install -y unzip > /dev/null
fi

has_yum=$(which yum)
if [ $? -eq 0 ]; then
  echo -e "\033[32m Update yum...\033[0m"
  echo -e "\033[32m================================================\033[0m"
  yum update -y
  yum install -y unzip > /dev/null
fi

unzip master.zip > /dev/null

if [[ ${CUSTOMIZE} = "true" ]]; then
  echo -e "\033[32m================================================\033[0m"
  echo -e "\033[32m Please make sure under kubecube folder     \033[0m"
  echo -e "\033[32m 'cd ./kubecube'                            \033[0m"
  echo -e "\033[32m Please modify ./manifests/install.conf     \033[0m"
  echo -e "\033[32m 'vi ./manifests/install.conf'              \033[0m"
  echo -e "\033[32m Please modify ./manifests/cube.conf        \033[0m"
  echo -e "\033[32m 'vi ./manifests/cube.conf'                 \033[0m"
  echo -e "\033[32m Confirm every args then do command below:  \033[0m"
  echo -e "\033[32m '/bin/bash ./manifests/install.sh'            \033[0m"
  echo -e "\033[32m================================================\033[0m"
  exit 0
fi

/bin/bash ./manifests/install.sh
