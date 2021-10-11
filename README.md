All manifests for deploying kubecube, deploy details please follow [doc](https://www.kubecube.io/docs/installation-guide/)

## Quick start
set version
```bash
KUBECUBE_VERSION=v1.0
```

### All in one install
```bash
curl -fsSL https://kubecube.nos-eastchina1.126.net/kubecube-installer/${KUBECUBE_VERSION}/entry.sh | bash
```

### Custom install
```bash
export CUSTOMIZE="true";curl -fsSL https://kubecube.nos-eastchina1.126.net/kubecube-installer/${KUBECUBE_VERSION}/entry.sh | bash
```

### Pre Download
```bash
export PRE_DOWNLOAD="true";curl -fsSL https://kubecube.nos-eastchina1.126.net/kubecube-installer/${KUBECUBE_VERSION}/entry.sh | bash
```

### Offline Download
```bash
k8s_version=1.20.9
os_arch=amd64
```

```bash
/bin/bash offline_pkg_download.sh ${k8s_version} ${os_arch}
```