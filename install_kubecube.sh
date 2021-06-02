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
echo -e "\033[32m>>>>>>	Render Values of KubeCube...\033[0m"
cat >values.yaml <<EOF
kubecube:
  env:
    pivotCubeHost: ${IPADDR}:30443

webhook:
  caBundle: $(cat ca/ca.crt | base64 -w 0)

tlsSecret:
  key: $(cat ca/tls.key | base64 -w 0)
  crt: $(cat ca/tls.crt | base64 -w 0)

caSecret:
  key: $(cat ca/ca.key | base64 -w 0)
  crt: $(cat ca/ca.crt | base64 -w 0)

pivotCluster:
  kubernetesAPIEndpoint: ${IPADDR}:6443
  kubeconfig: $(cat /root/.kube/config | base64 -w 0)
EOF
}

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	create namespace for kubecube...\033[0m"
kubectl apply -f manifests/ns/ns.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy frontend for kubecube...\033[0m"
kubectl apply -f manifests/frontend/frontend.yaml

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	deploy audit server for kubecube...\033[0m"
kubectl apply -f manifests/audit/audit.yaml

sign_cert
render_values
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Deploying KubeCube...\033[0m"
/usr/local/bin/helm install -f values.yaml kubecube manifests/kubecube/v0.0.1

echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m>>>>>>	Waiting For KubeCube ready...\033[0m"
echo
while true
do
  cube_healthz=$(curl -s -k https://${IPADDR}:30443/healthz)
  warden_healthz=$(curl -s -k https://${IPADDR}:31443/healthz)
  if [[ ${cube_healthz} = "healthy" && ${warden_healthz} = "healthy" ]]; then
    echo -e "\033[32m=============================================================\033[0m"
    echo -e "\033[32m=============================================================\033[0m"
    echo -e "\033[32m>>>>>>	            Welcome to KubeCube!               <<<<<<\033[0m"
    echo -e "\033[32m>>>>>>	      Please use 'admin/admin' to login        <<<<<<\033[0m"
    echo -e "\033[32m>>>>>>	              '${IPADDR}:30080'                <<<<<<\033[0m"
    echo -e "\033[32m>>>>>>	      You must change password after login     <<<<<<\033[0m"
    echo -e "\033[32m=============================================================\033[0m"
    echo -e "\033[32m=============================================================\033[0m"
    exit 0
  fi
  sleep 7 > /dev/null
done


