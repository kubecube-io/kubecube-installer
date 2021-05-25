#!/bin/bash

IPADDR=$(hostname -I |awk '{print $1}')

function sign_cert() {
mkdir -p ca
cd ca

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Generate ca key and ca cert...[0m"
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=*.kubecube-system.svc" -days 10000 -out ca.crt

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Generate tls key...\033[0m"
openssl genrsa -out tls.key 2048

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Make tls csr...\033[0m"
cat << EOF >csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = ch
ST = zj
L = hz
O = kubecube
CN = *.kubecube-system.svc

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.kubecube-system.svc
IP.1 = 127.0.0.1
IP.2 = ${IPADDR}

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF
openssl req -new -key tls.key -out tls.csr -config csr.conf

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Generate tls cert...\033[0m"
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 10000 -extensions v3_ext -extfile csr.conf
cd ..
}

function render_values() {
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	render values of KubeCube...\033[0m"
cat << EOF >values.yaml
kubecube:
  env:
    pivotCubeHost: ${IPADDR}:30443

webhook:
  caBundle: ${cat ca/ca.crt | base64}

tlsSecret:
  key: ${cat ca/tls.key | base64}
  crt: ${cat ca/tls.crt | base64}

pivotCluster:
  kubernetesAPIEndpoint: ${IPADDR}:6443
  kubeconfig: ${cat /root/.kube/config | base64}
EOF
}

sign_cert
render_values
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploying KubeCube...\033[0m"
helm install -f values.yaml kubecube kubecube/v0.0.1

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	        Welcome to KubeCube!       <<<<<<\033[0m"
echo -e "\033[32m================================================\033[0m"


