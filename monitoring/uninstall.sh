#!/usr/bin/env bash
# monitoring/uninstall.sh
# Phase 10 – Remove Prometheus + Grafana from EKS
#
# Use this to clean up before running `terraform destroy`,
# or if you need to start the monitoring stack fresh.
#
# Usage:
#   cd ~/study/final-project
#   bash monitoring/uninstall.sh

set -euo pipefail

NAMESPACE="monitoring"
RELEASE="kube-prom"

echo "=== Removing Observability Stack ==="
echo ""

echo "[1/3] Uninstalling Helm release '$RELEASE'..."
helm uninstall "$RELEASE" --namespace "$NAMESPACE" 2>/dev/null && \
  echo "      Helm release removed." || \
  echo "      Release not found (already uninstalled?)."

echo "[2/3] Deleting Grafana dashboard ConfigMap..."
kubectl delete configmap seyoawe-overview-dashboard -n "$NAMESPACE" 2>/dev/null && \
  echo "      ConfigMap deleted." || \
  echo "      ConfigMap not found."

echo "[3/3] Deleting namespace '$NAMESPACE'..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo ""
echo "Done. Prometheus + Grafana removed."
echo "(Terraform state and S3 backend are untouched — safe to re-apply anytime)"
