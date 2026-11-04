#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-kustomize}"
NAMESPACE="fiverr-club"

echo "========================================================"
echo " Deploying Fiverr Club Ecosystem to Kubernetes (${MODE})"
echo "========================================================"

if [[ "${MODE}" == "helm" ]]; then
  echo "[1/2] Deploying umbrella Helm v3 chart..."
  helm upgrade --install fiverr-ecosystem ./helm/fiverr-ecosystem \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f ./helm/fiverr-ecosystem/values.yaml
else
  echo "[1/2] Applying Kustomize manifests from ./k8s ..."
  kubectl apply -k ./k8s
fi

echo "[2/2] Waiting for StatefulSets and Core Workloads in namespace '${NAMESPACE}'..."
kubectl get pods -n "${NAMESPACE}"
echo "Deployment complete!"
