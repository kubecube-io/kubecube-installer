#!/usr/bin/env bash

source /etc/kubecube/manifests/utils.sh
source /etc/kubecube/manifests/install.conf

if [ $(kubectl get nodes | wc -l) -eq 2 ]
then
  echo "[WARN]delete taint of master node while only one node found"
  kubectl get nodes | grep -v "NAME" | awk '{print $1}' | sed -n '1p' | xargs -t -i kubectl taint node {} node-role.kubernetes.io/master- > /dev/null
  kubectl get nodes | grep -v "NAME" | awk '{print $1}' | sed -n '1p' | xargs -t -i kubectl taint node {} node-role.kubernetes.io/control-plane- > /dev/null
fi

if [ ! -z ${KUBERNETES_BIND_ADDRESS} ]; then
  IPADDR=${KUBERNETES_BIND_ADDRESS}
fi

function render_values() {
  clog info "render pivot values for kubecube chart values"
cat > render-values.yaml <<EOF
# pivot-value.yaml

global:
  # control-plane node IP which is used for exporting NodePort svc.
  nodeIP: ${IPADDR}

  dependencesEnable:
    ingressController: "${INGRESS_CONTROLLER_ENABLE}" # set "true" to deploy if ingress is not already in cluster.
    localPathStorage: "${LOCAL_PATH_STORAGE_ENABLE}"
    metricServer: "${METRIC_SERVER_ENABLE}"

  localKubeConfig: $(cat /root/.kube/config | base64 -w 0) # local cluster kubeconfig base64
  pivotKubeConfig: $(cat /root/.kube/config | base64 -w 0) # pivot cluster kubeconfig base64

warden:
  containers:
    warden:
      args:
        cluster: "pivot-cluster"  # set current cluster name
EOF
}

render_values

clog info "deploy kubecube"
/usr/local/bin/helm install kubecube -n ${INSTALL_NAMESPACE} --create-namespace /etc/kubecube/kubecube-chart -f ./render-values.yaml

