#!/bin/bash
# Get kubeconfig from the k3s master node
# Usage: ./get-kubeconfig.sh <master-public-ip>
#
# Or manually:
#   scp -i ~/.ssh/labsuser.pem ubuntu@<master-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig
#   sed -i '' 's/127.0.0.1/<master-public-ip>/g' ./kubeconfig

MASTER_IP="${1:-3.85.27.167}"
echo "Master node public IP: $MASTER_IP"
echo ""
echo "To get kubeconfig, run:"
echo "  scp -i ~/.ssh/labsuser.pem ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig"
echo "  sed -i '' 's/127.0.0.1/$MASTER_IP/g' ./kubeconfig"
echo "  export KUBECONFIG=./kubeconfig"
