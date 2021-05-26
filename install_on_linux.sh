#!/bin/bash

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	download manifests for kubecube...\033[0m"
wget https://gitee.com/kubecube/manifests/repository/archive/master.zip
yum install -y unzip > /dev/null
unzip  master.zip > /dev/null

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	make configurations...\033[0m"
sudo sh manifests/make_config.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing kubernetes...\033[0m"
sudo sh manifests/install_kubernetes.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing third dependence...\033[0m"
sudo sh manifests/install_third_dependence.sh

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	installing kubecube...\033[0m"
sudo sh manifests/install_kubecube.sh