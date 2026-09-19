#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
export SCW_PROFILE="newprofile"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for module in state-backend cluster storage jenkins monitoring; do
    echo "==> infra/$module"
    (cd "$ROOT/infra/$module" && terraform init -input=false -upgrade=false >/dev/null && terraform apply -auto-approve)
done

echo
echo "==> URLs"
"$ROOT/scripts/get-urls.sh"
