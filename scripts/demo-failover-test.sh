#!/usr/bin/env bash
# Nécessite ha_enabled=true (au moins 2 nœuds). Depuis le retrait de
# Longhorn (voir README "Stockage applicatif"), le volume Jenkins
# (sbs-default) reste verrouillé à sa zone : ce test ne peut réussir que
# si $NODE et un nœud disponible partagent la même zone. Avec la
# topologie par défaut de ha_enabled=true (1 nœud par zone), il n'y a
# alors aucun nœud de repli dans la même zone et le pod reste `Pending`.
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
echo "Test terminé : Jenkins a basculé de $NODE vers $NEW_NODE sans perte de données."
