#!/usr/bin/env bash
# Recreate the whole local cluster from nothing.
# Needs: docker, k3d, kubectl. Optional: argocd CLI.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-homelab}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.2}"
REPO_URL="${REPO_URL:-$(git remote get-url origin 2>/dev/null || true)}"
REPO_BRANCH="${REPO_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"

if [ -z "$REPO_URL" ]; then
  echo "No git remote found. Set REPO_URL=... (Argo CD pulls from git, not from your disk)." >&2
  exit 1
fi

echo "==> repo:   $REPO_URL @ $REPO_BRANCH"

# 1. cluster
if k3d cluster list | grep -qw "$CLUSTER_NAME"; then
  echo "==> cluster '$CLUSTER_NAME' already exists, reusing"
else
  k3d cluster create --config k3d/cluster.yaml
fi
kubectl config use-context "k3d-${CLUSTER_NAME}"

# 2. Argo CD itself (imperative on purpose - this is the bootstrap seam)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

# 3. hand over to git
sed -e "s|git@github.com:NilsEckerle/Homelab.git|${REPO_URL}|g" \
    -e "s|main|${REPO_BRANCH}|g" \
    clusters/local/root-app.yaml | kubectl apply -f -

cat <<MSG

==> done.

  UI:       kubectl -n argocd port-forward svc/argocd-server 8081:443
            https://localhost:8081   (user: admin)
  password: kubectl -n argocd get secret argocd-initial-admin-secret \\
              -o jsonpath='{.data.password}' | base64 -d; echo
  app:      kubectl -n podinfo port-forward svc/podinfo 9898:9898

MSG
