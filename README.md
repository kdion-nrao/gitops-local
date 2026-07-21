# Release Engineering GitOps local development

Setup a local k8s cluster (k3d) and ArgoCD for local experimentation, development, and debugging.

## Local kubernetes cluster

I used `k3d` running on docker for my local setup.

- `docker`: installed via `colima`, **NOT** Docker Desktop
    ```
    $ docker version
    Client: Docker Engine - Community
    Version:           29.5.3
    API version:       1.54
    Go version:        go1.26.4
    Git commit:        d1c06ef6b4
    Built:             Wed Jun  3 17:16:33 2026
    OS/Arch:           darwin/arm64
    Context:           colima

    Server: Docker Engine - Community
    Engine:
    Version:          29.5.2
    API version:      1.54 (minimum version 1.40)
    Go version:       go1.26.3
    Git commit:       568f755
    Built:            Wed May 20 14:39:25 2026
    OS/Arch:          linux/arm64
    Experimental:     false
    containerd:
    Version:          v2.2.4
    GitCommit:        193637f7ee8ae5f5aa5248f49e7baa3e6164966e
    runc:
    Version:          1.3.5
    GitCommit:        v1.3.5-0-g488fc13e
    docker-init:
    Version:          0.19.0
    GitCommit:        de40ad0
    ```
- Gave colima extra resources via `colima start --cpus 5 --memory 16 --mount-type virtiofs --vm-type=vz --vz-rosetta`
- `kubectl` using the [AWS/eks version](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#eksctl-install-update)
    ```
    $ kubectl version
    Client Version: v1.35.3-eks-bbe087e
    Kustomize Version: v5.7.1
    ```

[`k3d`](https://k3d.io/stable/)
- created a cluster:
    ```bash
    k3d cluster create --config k3d-cluster.yaml
    ```
    ```bash
    $ kubectl get nodes
    NAME                 STATUS   ROLES           AGE   VERSION
    k3d-local-server-0   Ready    control-plane   22m   v1.35.5+k3s1
    ```

[`helm`](https://helm.sh/docs/intro/install/)
```
brew install helm
```

## ArgoCD
```
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
```
kubectl get pods -n argocd
```

Install `argocd` cli
```
brew install argocd
```

Get default admin creds:
```
kubectl get secrets argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```
Or, using `argocd` cli:
```
argocd admin initial-password -n argocd
```

Login to server with `argocd`
```
argocd login localhost:8443
```

Port forward the dashboard:
```
kubectl port-forward svc/argocd-server -n argocd 8443:443
```
Then, access the web dashboard at https://localhost:8443/

### ArgoCD via Helm

```bash
# Add the ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd-values.yaml
```

Upgrading installation

```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f argocd-values.yaml
```

## Secrets

See [secrets.md](secrets.md)

### Installation
Install the [latest version](https://github.com/jkroepke/helm-secrets/releases/latest):

```bash
helm plugin install --verify=false https://github.com/jkroepke/helm-secrets/releases/download/v4.7.7/secrets-4.7.7.tgz
helm plugin install --verify=false https://github.com/jkroepke/helm-secrets/releases/download/v4.7.7/secrets-getter-4.7.7.tgz
helm plugin install --verify=false https://github.com/jkroepke/helm-secrets/releases/download/v4.7.7/secrets-post-renderer-4.7.7.tgz
```

## dummyapp

```
kubectl apply -f envs/dev/dummyapp-application.yaml
```

## Helpful commands

### View Traefik logs
```
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}')
```
