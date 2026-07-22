# Release Engineering GitOps local development

Setup a local k8s cluster (k3d) and ArgoCD for local experimentation, development, and debugging.

## Local kubernetes cluster

I used [`k3d`](https://k3d.io/stable/) running on docker for my local setup.

- `docker`: installed via `colima`, **NOT** Docker Desktop
- Gave colima extra resources via `colima start --cpus 5 --memory 16 --mount-type virtiofs --vm-type=vz --vz-rosetta`
- `kubectl` using the [AWS/eks version](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#eksctl-install-update)
- [`helm`](https://helm.sh/docs/intro/install/)
- [`sops`](https://getsops.io/) for secrets management
- [`age`](https://github.com/FiloSottile/age) for pki encryption

### Quickstart

You should be able to create and setup a full local k3d cluster with ArgoCD by running:
```bash
# Install dependencies (macOS)
brew install -y k3d helm argocd age

# Setup the k3d cluster
./bootstrap.sh
```

Once it's complete, you should pretty soon be able to see:

https://dummy.localhost/dev/


### Manual

Create a k3d cluster:
```bash
k3d cluster create --config k3d-cluster.yaml
```

### TLS Termination via Traefik

Generate a self-signed cert:
```bash
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout tls.key -out tls.crt \
    -subj "/CN=*.localhost"
```

Store the cert in a Kubernetes Secret for Traefik
```bash
kubectl create ns traefik
kubectl create secret tls local-selfsigned-tls \
    --cert=tls.crt --key=tls.key \
    --namespace traefik
```

#### Install Traefik
Add Repos
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

Install
```bash
helm install traefik traefik/traefik  \
  --namespace traefik \
  -f traefik-values.yaml --wait
```

View the Trafeik dashboard at: https://traefik.localhost/dashboard/

## ArgoCD

### Setup

Store the cert in a Kubernetes Secret
```bash
kubectl create ns argocd
kubectl create secret tls local-selfsigned-tls \
    --cert=tls.crt --key=tls.key \
    --namespace argocd
```

Add your [`age`](https://github.com/FiloSottile/age) key as a Secret for ArgoCD
```bash
kubectl -n argocd create secret generic helm-secrets-private-keys --from-file=key.txt=your/age/key.txt
```

Add the ArgoCD Helm repository
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Install

Install the argocd Helm chart
```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd-values.yaml
```

Create the Ingress for https://argocd.localhost/
```bash
kubectl apply -f argocd-ingress.yaml
```

### Upgrading
```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f argocd-values.yaml
```

### CLI
Install `argocd` cli
```bash
brew install argocd
```

Get default admin creds:
```bash
argocd admin initial-password -n argocd
```

Login to server with `argocd`
```bash
argocd login argocd.localhost
```

## ArgoCD Apps
Root App-of-Apps:
```bash
kubectl apply -f variants/local/root.yaml
```

## Helpful commands

### View Traefik logs
```
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}')
```
