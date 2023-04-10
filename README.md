# KubeCube-Installer

KubeCube installer is here for install kubecube by "all-in-one" way. More details follow [doc](https://www.kubecube.io/docs/installation-guide/).

## Quick start

set version

```bash
export KUBECUBE_VERSION=v1.8
```

### All in one install

```bash
curl -fsSL https://kubecube.nos-eastchina1.126.net/kubecube-installer/release/v1.3/entry.sh | bash
```

### Custom install

```bash
export CUSTOMIZE="true";curl -fsSL https://kubecube.nos-eastchina1.126.net/kubecube-installer/release/v1.3/entry.sh | bash
```

## Clean UP

```bash
curl -o cleanup.sh https://kubecube.nos-eastchina1.126.net/hack/cleanup.sh
```

```bash
# params can be: 'kubecube','k8s','docker','containerd','all'
/bin/bash cleanup.sh all
```