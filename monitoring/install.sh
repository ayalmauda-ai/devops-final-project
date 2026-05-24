#!/usr/bin/env bash
# monitoring/install.sh
# Phase 10 – Deploy Prometheus + Grafana to EKS via Helm
#
# Prerequisites (all already installed per Phase 0 checklist):
#   - helm, kubectl, aws cli
#   - EKS cluster reachable:  kubectl get nodes
#   - ingress-nginx installed (Phase 8/9 Ansible did this)
#
# Usage:
#   cd ~/study/final-project
#   bash monitoring/install.sh

set -euo pipefail

NAMESPACE="monitoring"
RELEASE="kube-prom"
CHART="prometheus-community/kube-prometheus-stack"
VALUES="monitoring/values-prometheus.yaml"
DASHBOARD_CM="monitoring/dashboard-configmap.yaml"

echo "=== Phase 10 – Observability Stack ==="
echo ""

# ── 1. Add / update Helm repo ────────────────────────────────────────────────
echo "[1/5] Adding prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# ── 2. Create namespace ───────────────────────────────────────────────────────
echo "[2/5] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── 3. Apply Grafana dashboard ConfigMap ──────────────────────────────────────
echo "[3/5] Applying Grafana dashboard ConfigMap..."
kubectl apply -f "$DASHBOARD_CM"

# ── 4. Helm install / upgrade ─────────────────────────────────────────────────
echo "[4/5] Running helm upgrade --install $RELEASE ..."
echo "      (This can take 3–5 minutes while EBS volumes and pods start)"
helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NAMESPACE" \
  --values "$VALUES" \
  --atomic \
  --timeout 10m \
  --create-namespace

# ── 5. Print access info ──────────────────────────────────────────────────────
echo ""
echo "[5/5] Done! Fetching access details..."
echo ""

# Get the NLB hostname that ingress-nginx created
NLB_HOST=$(kubectl get svc -n ingress-nginx \
  -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<pending>")

echo "==========================================================="
echo "  Grafana URL:  http://${NLB_HOST}/grafana"
echo "  Username:     admin"
echo "  Password:     DevOps2026!   ← change this after first login"
echo ""
echo "  If NLB hostname shows '<pending>', wait 60s and run:"
echo "    kubectl get svc -n ingress-nginx"
echo ""
echo "  Dashboard: seyoawe Engine – Overview"
echo "    (auto-loaded from ConfigMap; may take 30s to appear in Grafana)"
echo "==========================================================="
