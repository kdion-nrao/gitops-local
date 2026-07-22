#!/usr/bin/env bash
set -eEuo pipefail

error_handler() {
    local exit_code=$?
    local line_number=$1
    echo "[ERROR] Command failed with exit code $exit_code at line $line_number" >&2
}

trap 'error_handler $LINENO' ERR

line() {
    local len="${1:-40}"
    local ch="${2:-=}"
    printf '%*s\n' "$len" '' | tr ' ' "$ch"
}

banner() {
    local message="$1"
    local len=40
    line "$len" "="
    printf "%*s\n" $(( (${#message} + 40) / 2)) "$message"
    line "$len" "="
}

check_tools() {
    banner "Checking for tools"

    local needed_tools=(
        "k3d"
        "kubectl"
        "helm"
        "argocd"
        "age"
    )

    for tool in "${needed_tools[@]}"
    do
        echo -n "Checking for $tool..."
        if ! command -v "$tool" >/dev/null 2>&1
        then
            echo "NOT FOUND"
            echo "[ERROR] '$tool' not found - install it and run this script again."
            exit 1
        else
            echo "OK"
        fi
    done
}

check_existing_cluster() {
    if k3d cluster list | grep -qe '^local\s' 2>/dev/null
    then
        echo "[ERROR] The 'local' cluster already exists!"
        echo "If you want to recreate it, delete it first by running:"
        echo ""
        echo "   k3d cluster delete local"
        echo ""
        exit 1
    fi
}

create_k3d_cluster() {
    banner "Creating k3d cluster"
    check_existing_cluster

    k3d cluster create --config k3d-cluster.yaml

    if ! kubectl config current-context | grep -qe '^k3d-local' 2>/dev/null
    then
        kubectl config use-context k3d-local
    fi
}

create_cert() {
    banner "Creating self-signed certificate"

    if [ -f "tls.key" ] && [ -f "tls.crt" ]
    then
        echo "Already exists"
    else
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout tls.key -out tls.crt \
        -subj "/CN=*.localhost"
    fi
}

install_traefik() {
    banner "Installing Traefik"

    if ! kubectl get ns traefik 2>/dev/null
    then
        echo "Creating namespace"
        kubectl create ns traefik
    fi

    if ! kubectl get secret -n traefik local-selfsigned-tls 2>/dev/null
    then
        echo "Creating the certificate secret"
        kubectl create secret tls local-selfsigned-tls \
            --cert=tls.crt --key=tls.key \
            --namespace traefik
    fi

    if ! helm repo list | grep -qe '^traefik\s' 2>/dev/null
    then
        echo "Adding the helm repo"
        helm repo add traefik https://traefik.github.io/charts
    fi
    helm repo update

    echo "Installing Traefik Helm chart"
    helm install traefik traefik/traefik  \
        --namespace traefik \
        -f traefik-values.yaml --wait

    line 40 "-"
    echo "Done! Access the Traefik dashboard at:"
    echo "   https://traefik.localhost/dashboard/"
    echo ""
}

install_argo() {
    banner "Installing ArgoCD"

    if ! kubectl get ns argocd 2>/dev/null
    then
        echo "Adding namespace"
        kubectl create ns argocd
    fi

    if ! kubectl get secret -n argocd local-selfsigned-tls 2>/dev/null
    then
        echo "Creating the certificate secret"
        kubectl create secret tls local-selfsigned-tls \
            --cert=tls.crt --key=tls.key \
            --namespace argocd
    fi

    if ! [ -f "${HOME}/.config/sops/age/keys.txt" ]
    then
        mkdir -p "${HOME}/.config/sops/age"
        age-keygen -o "${HOME}/.config/sops/age/keys.txt"
    fi
    kubectl -n argocd create secret generic \
        helm-secrets-private-keys \
        --from-file=key.txt="${HOME}/.config/sops/age/keys.txt"

    if ! helm repo list | grep -qe '^argo\s' 2>/dev/null
    then
        echo "Adding the helm repo"
        helm repo add argo https://argoproj.github.io/argo-helm
    fi
    helm repo update

    echo "Installing ArgoCD Helm chart"
    helm install argocd argo/argo-cd \
        --namespace argocd \
        -f argocd-values.yaml --wait

    kubectl apply -f argocd-ingress.yaml

    argo_pwd=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    argocd login argocd.localhost \
        --username admin \
        --password "$argo_pwd" \
        --insecure
    
    line 40 "-"
    echo "Done! Access the ArgoCD dashboard at:"
    echo "   https://argocd.localhost/"
    echo ""
    echo "The default admin password is:"
    echo "$argo_pwd"
}

install_root_app() {
    banner "Installing Root Argo App"
    kubectl apply -f variants/local/root.yaml
}

check_tools
create_k3d_cluster
create_cert
install_traefik
install_argo
install_root_app

echo "Done!"
