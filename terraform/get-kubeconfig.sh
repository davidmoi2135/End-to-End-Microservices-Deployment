#!/bin/bash
# Fetch kubeconfig from the k3s master.
# ALB is L7 and cannot proxy the kube API, so the kubeconfig points
# directly at the master's public IP.
set -euo pipefail

MASTER_IP="${1:-13.212.241.178}"
KEY="${SSH_KEY:-./k3s-key.pem}"

echo "Fetching kubeconfig from $MASTER_IP ..."
ssh -o StrictHostKeyChecking=no -i "$KEY" ubuntu@"$MASTER_IP" \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed "s|https://127.0.0.1:6443|https://$MASTER_IP:6443|" > ./kubeconfig
chmod 600 ./kubeconfig

echo "Done. Run:"
echo "  export KUBECONFIG=$(pwd)/kubeconfig"
echo "  kubectl get nodes"
