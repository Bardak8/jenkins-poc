#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
export SCW_PROFILE="newprofile"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Vidage des nœuds fr-par-1/fr-par-3 avant suppression (évite les VolumeAttachment orphelins)"
for node in $(kubectl get nodes -o name | grep -E "fr-par-1-ha|fr-par-3-ha" | sed 's|node/||'); do
    kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=120s || true
done

echo
echo "==> Retour à 1 nœud (fr-par-2), économie des coûts fr-par-1/fr-par-3"
(cd "$ROOT/infra/cluster" && terraform apply -auto-approve -var="ha_enabled=false")

echo
echo "==> Nœuds"
kubectl get nodes -L topology.kubernetes.io/zone
