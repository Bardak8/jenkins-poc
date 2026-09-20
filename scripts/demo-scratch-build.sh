#!/usr/bin/env bash
# Scénario vidéo : construction complète depuis zéro, cluster à 3 nœuds
# multi-zone dès le premier apply (pas le mode 1 nœud par défaut).
# `infra/state-backend/` n'est jamais touché (voir README, il ne doit
# jamais dépendre d'un test de reconstruction).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCW_PROFILE="newprofile"

echo "==> [1/3] Destruction complète (hors state-backend)"
for module in backup monitoring apps ingress relay jenkins cluster; do
    echo "  -- infra/$module"
    (cd "$ROOT/infra/$module" && terraform destroy -auto-approve)
done

echo
echo "==> [2/3] Cluster à 3 nœuds dès le premier apply (ha_enabled=true)"
(cd "$ROOT/infra/cluster" && terraform apply -auto-approve -var="ha_enabled=true")

echo
echo "==> [3/3] Reconstruction du reste (config only, aucune donnée à restaurer ici)"
for module in jenkins relay ingress apps monitoring backup; do
    echo "  -- infra/$module"
    (cd "$ROOT/infra/$module" && terraform init -input=false -upgrade=false >/dev/null && terraform apply -auto-approve)
done

echo
export KUBECONFIG=$(mktemp)
(cd "$ROOT/infra/jenkins" && terraform output -raw kubeconfig > "$KUBECONFIG")

echo "==> Nœuds (3 zones)"
kubectl get nodes -L topology.kubernetes.io/zone

echo
echo "==> isaac-postgres (primaire + réplique, doivent être sur 2 nœuds différents)"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide

echo
"$ROOT/scripts/get-urls.sh"
