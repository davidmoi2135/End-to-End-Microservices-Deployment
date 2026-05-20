#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="staging"
APPLY_APP=false
SYNC_APP=false
WATCH_PODS=false

usage() {
  cat <<'EOF'
Usage:
  scripts/check-cicd-argocd-flow.sh [options]

Options:
  --env staging|production   Target GitOps environment. Default: staging
  --apply-app                Apply the ArgoCD Application manifest
  --sync-app                 Sync the ArgoCD app if argocd CLI is available
  --watch-pods               Watch target namespace pods after checks
  -h, --help                 Show help

Examples:
  scripts/check-cicd-argocd-flow.sh --env staging
  scripts/check-cicd-argocd-flow.sh --env staging --apply-app --watch-pods
  scripts/check-cicd-argocd-flow.sh --env production --apply-app --sync-app

Notes:
  This script does not push code, does not edit CI/CD files, and does not build images.
  It checks whether the CI/CD and GitOps wiring is ready for:
    GitHub Actions -> Docker Hub -> ArgoCD -> Kubernetes
EOF
}

log() {
  printf '\n[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
}

ok() {
  printf '[ OK ] %s\n' "$*"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

search_quiet() {
  local pattern="$1"
  shift

  if has_cmd rg; then
    rg -q "$pattern" "$@"
  else
    grep -R -q -E "$pattern" "$@"
  fi
}

search_lines() {
  local pattern="$1"
  shift

  if has_cmd rg; then
    rg -n "$pattern" "$@"
  else
    grep -R -n -E "$pattern" "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --apply-app)
      APPLY_APP=true
      shift
      ;;
    --sync-app)
      SYNC_APP=true
      shift
      ;;
    --watch-pods)
      WATCH_PODS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

case "$ENVIRONMENT" in
  staging)
    EXPECTED_BRANCH="dev"
    K8S_PATH="spring-boot-app/k8s-staging"
    APP_MANIFEST="argocd/staging-app.yaml"
    APP_NAME="spring-microservices-staging"
    NAMESPACE="spring-microservices-staging"
    EXPECTED_TAG="dev"
    ;;
  production)
    EXPECTED_BRANCH="main"
    K8S_PATH="spring-boot-app/k8s"
    APP_MANIFEST="argocd/production-app.yaml"
    APP_NAME="spring-microservices"
    NAMESPACE="spring-microservices"
    EXPECTED_TAG="main"
    ;;
  *)
    fail "--env must be staging or production"
    exit 2
    ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

log "Checking repository and toolchain"
for cmd in git docker kubectl; do
  if has_cmd "$cmd"; then
    ok "$cmd is available"
  else
    fail "$cmd is missing"
    exit 1
  fi
done

if has_cmd gh; then
  ok "gh CLI is available"
else
  warn "gh CLI is not available; GitHub Actions run status will be skipped"
fi

if has_cmd argocd; then
  ok "argocd CLI is available"
else
  warn "argocd CLI is not available; --sync-app cannot run unless you install/login argocd CLI"
fi

CURRENT_BRANCH="$(git branch --show-current)"
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
printf 'Current branch: %s\n' "$CURRENT_BRANCH"
printf 'Origin remote:   %s\n' "${REMOTE_URL:-not configured}"

if [[ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  warn "Current branch is '$CURRENT_BRANCH', but '$ENVIRONMENT' GitOps expects '$EXPECTED_BRANCH'"
  warn "For the full CI/CD flow, push/merge the code to '$EXPECTED_BRANCH'"
else
  ok "Branch matches $ENVIRONMENT target"
fi

if [[ -n "$(git status --short)" ]]; then
  warn "Working tree has uncommitted changes. ArgoCD will not see them until committed and pushed."
  git status --short
else
  ok "Working tree is clean"
fi

log "Checking GitHub Actions workflows"
WORKFLOW_COUNT="$(find .github/workflows -maxdepth 1 -type f -name '*-ci.yaml' | wc -l | tr -d ' ')"
printf 'Workflow files: %s\n' "$WORKFLOW_COUNT"

if [[ "$WORKFLOW_COUNT" -lt 1 ]]; then
  fail "No workflow files found under .github/workflows"
  exit 1
fi

if search_quiet 'branches: \[ "main", "dev" \]' .github/workflows; then
  ok "Workflows are configured for main/dev pushes"
else
  warn "Could not confirm main/dev branch triggers in workflows"
fi

if search_quiet 'paths:' .github/workflows; then
  ok "Some workflows use path filters"
else
  warn "No workflow path filters found; every push to main/dev may trigger every service workflow"
fi

if search_quiet 'mvn clean verify -DskipTests' .github/workflows; then
  warn "Maven workflows currently skip tests with -DskipTests"
fi

if search_quiet 'aquasecurity/trivy-action' .github/workflows; then
  ok "Trivy image scan is configured"
else
  warn "Trivy scan was not found"
fi

log "Checking Docker image naming"
KUSTOMIZE_FILE="$K8S_PATH/kustomization.yaml"
if [[ ! -f "$KUSTOMIZE_FILE" ]]; then
  fail "Missing $KUSTOMIZE_FILE"
  exit 1
fi

DOCKER_NAMESPACE="$(awk '/name: / && $3 ~ /\// { split($3, parts, "/"); print parts[1]; exit }' "$KUSTOMIZE_FILE")"
printf 'Kustomize image namespace: %s\n' "${DOCKER_NAMESPACE:-unknown}"

if [[ -n "${DOCKER_USERNAME:-}" && -n "$DOCKER_NAMESPACE" && "$DOCKER_USERNAME" != "$DOCKER_NAMESPACE" ]]; then
  warn "DOCKER_USERNAME='$DOCKER_USERNAME' does not match kustomize namespace '$DOCKER_NAMESPACE'"
fi

if search_quiet "newTag: $EXPECTED_TAG" "$KUSTOMIZE_FILE"; then
  ok "Kustomize uses expected image tag '$EXPECTED_TAG'"
else
  warn "$KUSTOMIZE_FILE may not use expected tag '$EXPECTED_TAG'"
fi

log "Rendering Kubernetes manifests"
if kubectl kustomize "$K8S_PATH" >/tmp/vshop-rendered-"$ENVIRONMENT".yaml; then
  ok "kubectl kustomize $K8S_PATH rendered successfully"
else
  fail "kubectl kustomize $K8S_PATH failed"
  exit 1
fi

if search_quiet 'kind: Rollout' "$K8S_PATH"; then
  warn "$K8S_PATH contains Argo Rollouts resources; the cluster needs the Rollout CRD installed"
fi

log "Checking Kubernetes/ArgoCD cluster access"
if kubectl cluster-info >/dev/null 2>&1; then
  ok "kubectl can reach the cluster"
  kubectl get nodes
else
  warn "kubectl cannot reach the cluster. Start k3d or select the right context first."
fi

if kubectl get namespace argocd >/dev/null 2>&1; then
  ok "argocd namespace exists"
  kubectl get pods -n argocd
else
  warn "argocd namespace does not exist or cluster is unreachable"
fi

if kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
  ok "Argo Rollouts CRD is installed"
else
  warn "Argo Rollouts CRD is not installed; Rollout manifests will fail to sync"
fi

log "Checking ArgoCD Application manifest"
if [[ -f "$APP_MANIFEST" ]]; then
  ok "$APP_MANIFEST exists"
  search_lines 'repoURL|targetRevision|path:|namespace:' "$APP_MANIFEST" || true
else
  fail "Missing $APP_MANIFEST"
  exit 1
fi

if "$APPLY_APP"; then
  log "Applying $APP_MANIFEST"
  kubectl apply -f "$APP_MANIFEST"
fi

if "$SYNC_APP"; then
  log "Syncing ArgoCD app $APP_NAME"
  if has_cmd argocd; then
    argocd app sync "$APP_NAME"
  else
    fail "argocd CLI is missing; cannot sync with --sync-app"
    exit 1
  fi
fi

if kubectl get applications.argoproj.io "$APP_NAME" -n argocd >/dev/null 2>&1; then
  ok "ArgoCD application '$APP_NAME' exists"
  kubectl get applications.argoproj.io "$APP_NAME" -n argocd
else
  warn "ArgoCD application '$APP_NAME' is not present yet. Use --apply-app or apply $APP_MANIFEST manually."
fi

if has_cmd gh; then
  log "Recent GitHub Actions runs for branch $EXPECTED_BRANCH"
  gh run list --branch "$EXPECTED_BRANCH" --limit 10 || warn "Could not read GitHub Actions runs. Check gh auth/login."
fi

log "Next manual steps for the full CI/CD flow"
cat <<EOF
1. Commit and push code to '$EXPECTED_BRANCH'.
2. Wait for GitHub Actions to build and push Docker images tagged '$EXPECTED_TAG'.
3. Apply/sync the ArgoCD app:
     kubectl apply -f $APP_MANIFEST
4. Watch deployment:
     kubectl get pods -n $NAMESPACE -w
5. Test app:
     staging frontend:   http://localhost:31000
     staging gateway:    http://localhost:31085
     production frontend: http://localhost:30000
     production gateway:  http://localhost:30085
EOF

if "$WATCH_PODS"; then
  log "Watching pods in $NAMESPACE"
  kubectl get pods -n "$NAMESPACE" -w
fi
