#!/bin/bash -e

if k3d cluster list | grep -qe '^local\s' 2>/dev/null
then
    echo "ERROR: The 'local' cluster already exists!"
    echo "If you want to recreate it, delete it first by running:"
    echo ""
    echo "   k3d cluster delete local"
    echo ""
    exit 1
fi

echo "=============================="
echo "     Creating k3d cluster"
echo "=============================="

k3d cluster create --config k3d-cluster.yaml

if ! kubectl config current-context | grep -qe '^k3d-local' 2>/dev/null
then
    kubectl config use-context k3d-local
fi

echo "=============================="
echo "  Installing ArgoCD via Helm"
echo "=============================="

if ! helm repo list | grep -qe '^argo\s' 2>/dev/null
then
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
fi

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd-values.yaml

kubectl apply -f argocd-ingress.yaml

echo "-----------------------------"
echo "ArgoCD Installed. Access it at https://argocd.localhost:8081/"
echo "The initial admin password is:"

argocd admin initial-password -n argocd

echo "-----------------------------"
echo "Adding the private GH repo"
kubectl apply -f common/secret-github-repo.yaml
