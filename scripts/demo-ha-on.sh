#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
export SCW_PROFILE="newprofile"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Passage à 3 nœuds (fr-par-1, fr-par-2, fr-par-3)"
(cd "$ROOT/infra/cluster" && terraform apply -auto-approve -var="ha_enabled=true")

echo
echo "==> Nœuds"
kubectl get nodes -L topology.kubernetes.io/zone
