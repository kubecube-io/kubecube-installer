#!/bin/bash

if [ ${UID} -ne 0 ];then
  echo -e "\033[32m please use root to execute install shell...\033[0m"
  exit 1
fi

mkdir kubecube
cd kubecube

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m Download manifests for kubecube...\033[0m"
wget https://gitee.com/kubecube/manifests/repository/archive/master.zip

has_apt=$(which apt)
if [ ! -z ${has_apt} ]; then
  apt-get update -y
  apt-get install -y unzip > /dev/null
fi

has_yum=$(which yum)
if [ $? -eq 0 ]; then
  yum update -y
  yum install -y unzip > /dev/null
fi

unzip master.zip > /dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m     please make sure under kubecube folder     \033[0m"
echo -e "\033[32m     please modify ./manifests/install.conf     \033[0m"
echo -e "\033[32m  	  'vi ./manifests/install.conf'              \033[0m"
echo -e "\033[32m    	confirm every args then do command below:  \033[0m"
echo -e "\033[32m     '/bin/bash ./manifests/main.sh'         \033[0m"
echo -e "\033[32m================================================\033[0m"
