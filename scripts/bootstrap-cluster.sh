#!/usr/bin/env bash
# Bootstrap a freshly-created k3s cluster:
#   1. Install ArgoCD into the `argocd` namespace
#   2. Install ArgoCD Image Updater
#   3. Install Argo Rollouts (canary / blue-green controller)
#   4. Install cert-manager (TLS / Let's Encrypt ClusterIssuer)
#   5. Create git-creds secret (GitHub PAT) for Image Updater write-back
#   6. Create app namespaces and apply user-supplied secrets
#   7. Register the two ArgoCD Application CRs (dev + production)
#
# Prerequisites:
#   - `terraform apply` already finished and `kubectl get nodes` works
#   - KUBECONFIG env var points to the cluster kubeconfig
#   - Repo checked out on `main` branch (we still need `origin/dev` fetched)
#
# Usage:
#   export KUBECONFIG=/path/to/kubeconfig
#   ./scripts/bootstrap-cluster.sh
#
# Re-runs are safe — every step is idempotent (kubectl apply / || true).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ARGOCD_NS=argocd
ROLLOUTS_NS=argo-rollouts
ROLLOUTS_VERSION=v1.7.2
CERTMGR_NS=cert-manager
CERTMGR_VERSION=v1.15.3
DEV_NS=spring-microservices-dev
PROD_NS=spring-microservices

# ---------- helpers ----------
log()  { printf '\n\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[warn]\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31m[fail]\e[0m %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

# ---------- preflight ----------
log "Preflight checks"
require_cmd kubectl
require_cmd git
[ -n "${KUBECONFIG:-}" ] || die "KUBECONFIG env var not set"
[ -r "$KUBECONFIG" ]     || die "KUBECONFIG file not readable: $KUBECONFIG"

kubectl cluster-info >/dev/null 2>&1 \
  || die "kubectl cannot reach the cluster — check KUBECONFIG"

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "  cluster reachable, $NODE_COUNT node(s) found"

# ---------- step 1: install ArgoCD ----------
log "Step 1/7 — Install ArgoCD"
kubectl create namespace "$ARGOCD_NS" --dry-run=client -o yaml | kubectl apply -f -

# Use server-side apply: the ApplicationSet CRD is > 256KB and client-side
# apply fails with "metadata.annotations: Too long" because it stores the
# entire manifest in last-applied-configuration.
kubectl apply --server-side --force-conflicts -n "$ARGOCD_NS" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "  waiting for ArgoCD core deployments to become Available..."
kubectl -n "$ARGOCD_NS" wait --for=condition=Available \
  deploy/argocd-server deploy/argocd-repo-server deploy/argocd-applicationset-controller \
  --timeout=600s

# ---------- step 2: install Image Updater ----------
log "Step 2/7 — Install ArgoCD Image Updater"
IU_MANIFEST="argocd-image-updater-0.16.0/manifests/install.yaml"
if [ ! -f "$IU_MANIFEST" ]; then
  die "Image Updater manifest not found at $IU_MANIFEST"
fi
kubectl apply --server-side --force-conflicts -n "$ARGOCD_NS" -f "$IU_MANIFEST"
kubectl -n "$ARGOCD_NS" rollout status deploy/argocd-image-updater --timeout=300s || true

# ---------- step 3: install Argo Rollouts ----------
log "Step 3/7 — Install Argo Rollouts ($ROLLOUTS_VERSION)"
kubectl create namespace "$ROLLOUTS_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n "$ROLLOUTS_NS" \
  -f "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/install.yaml"
kubectl -n "$ROLLOUTS_NS" rollout status deploy/argo-rollouts --timeout=300s || true

# ---------- step 4: install cert-manager ----------
log "Step 4/7 — Install cert-manager ($CERTMGR_VERSION)"
kubectl apply --server-side --force-conflicts \
  -f "https://github.com/cert-manager/cert-manager/releases/download/${CERTMGR_VERSION}/cert-manager.yaml"
echo "  waiting for cert-manager deployments..."
kubectl -n "$CERTMGR_NS" wait --for=condition=Available \
  deploy/cert-manager deploy/cert-manager-webhook deploy/cert-manager-cainjector \
  --timeout=300s

# ---------- step 5: git-creds secret ----------
log "Step 5/7 — Configure Git credentials for Image Updater write-back"

if kubectl -n "$ARGOCD_NS" get secret git-creds >/dev/null 2>&1; then
  echo "  Secret 'git-creds' already exists — keeping it."
  echo "  Delete and re-run to update: kubectl -n $ARGOCD_NS delete secret git-creds"
else
  echo "  Need a GitHub Personal Access Token with 'repo' scope so Image Updater"
  echo "  can push digest bumps to main + dev branches."
  read -rp "  GitHub username: " GH_USER
  read -rsp "  GitHub PAT (input hidden): " GH_PAT; echo
  [ -n "$GH_USER" ] && [ -n "$GH_PAT" ] \
    || die "username/PAT cannot be empty"

  kubectl -n "$ARGOCD_NS" create secret generic git-creds \
    --from-literal=username="$GH_USER" \
    --from-literal=password="$GH_PAT"
  echo "  git-creds secret created."
fi

# ---------- step 6: namespaces + app secrets ----------
log "Step 6/7 — Create app namespaces"
kubectl create namespace "$DEV_NS"  --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$PROD_NS" --dry-run=client -o yaml | kubectl apply -f -

apply_secret_if_present() {
  local file="$1" ns="$2"
  if [ -f "$file" ]; then
    echo "  applying $file → namespace $ns"
    kubectl apply -n "$ns" -f "$file"
  else
    warn "Secret file '$file' not found — skipping. Create it from secret-example.yaml then re-run."
  fi
}

apply_secret_if_present "spring-boot-app/k8s/secrets.yaml" "$PROD_NS"
# secrets.yaml for dev typically lives in the same place when checked out on dev branch.
# If you keep a separate copy locally, override here:
apply_secret_if_present "${DEV_SECRETS_FILE:-/tmp/secrets-dev.yaml}" "$DEV_NS"

# Notification ConfigMap + Secret (Slack) — only if user prepared the real secret
if [ -f "argocd/notifications-cm.yaml" ]; then
  kubectl apply -n "$ARGOCD_NS" -f argocd/notifications-cm.yaml
fi
apply_secret_if_present "${NOTIF_SECRET_FILE:-argocd/notifications-secret.yaml}" "$ARGOCD_NS"

# ---------- step 7: register Applications ----------
log "Step 7/7 — Register ArgoCD Applications"

echo "  applying production app (from current branch HEAD)"
kubectl apply -f argocd/production-app.yaml

echo "  fetching dev branch to read dev-app.yaml"
git fetch origin dev --quiet || die "git fetch origin dev failed"
echo "  applying dev app (from origin/dev)"
git show origin/dev:argocd/dev-app.yaml | kubectl apply -f -

# ---------- summary ----------
log "Done — current Applications:"
kubectl -n "$ARGOCD_NS" get applications

cat <<EOF

==================================================================
Next steps
==================================================================
1. Get ArgoCD admin password:
     kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret \\
       -o jsonpath='{.data.password}' | base64 -d; echo

2. Open ArgoCD UI:
     kubectl -n $ARGOCD_NS port-forward svc/argocd-server 8080:443
     # then browse to https://localhost:8080  (user: admin)

3. Wait a few minutes for both Applications to reach Synced/Healthy.
   - $DEV_NS  : auto-syncs every commit on 'dev' branch
   - $PROD_NS : MANUAL sync (auto-sync disabled for safety)
                Open the app in UI, review diff, click 'Sync' to deploy.

4. Apps reachable through the ALB:
     terraform -chdir=terraform output -raw alb_dns_name

5. SECURITY: rotate any AWS access key you pasted in chat earlier.
==================================================================
EOF
