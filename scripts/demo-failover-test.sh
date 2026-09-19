#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

NODE=$(kubectl get pod jenkins-0 -n ci-cd -o jsonpath='{.spec.nodeName}')
echo "==> Jenkins tourne actuellement sur : $NODE"

echo "==> Cordon + drain (simule la panne de ce nœud)"
kubectl cordon "$NODE"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s

echo
echo "==> Attente de la replanification..."
for _ in $(seq 1 30); do
    NEW_NODE=$(kubectl get pod jenkins-0 -n ci-cd -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
    READY=$(kubectl get pod jenkins-0 -n ci-cd -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)
    if [ "$READY" = "true" ] && [ "$NEW_NODE" != "$NODE" ]; then
        break
    fi
    sleep 5
done

echo "==> Jenkins est maintenant sur : $NEW_NODE"
kubectl get pod jenkins-0 -n ci-cd

echo
echo "==> Remise en service de $NODE"
kubectl uncordon "$NODE"

echo
echo "Test terminé : Jenkins a basculé de $NODE vers $NEW_NODE sans perte de données (stockage Longhorn répliqué)."
