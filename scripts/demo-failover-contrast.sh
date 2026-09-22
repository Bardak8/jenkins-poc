#!/usr/bin/env bash
# Scénario vidéo : deux mécanismes de résilience différents, chacun
# adapté à la nature du composant. isaac-postgres (CloudNativePG)
# réplique en continu au niveau applicatif et bascule par promotion
# du réplica synchronisé. Jenkins (Longhorn) réplique le volume au
# niveau du stockage bloc et redémarre sur un autre nœud avec ses
# données intactes. Les deux survivent à la perte d'un nœud.
#
# Les deux simulent la même chose (perte brutale du nœud, pas une
# maintenance planifiée) : suppression forcée du pod sans arrêt
# propre (--grace-period=0 --force), jamais `kubectl drain`. Un vrai
# drain évince TOUT ce qui tourne sur le nœud (Longhorn
# instance-manager protégé par PDB, gateways WireGuard, monitoring...,
# constaté en vrai) et fait un arrêt propre, pas un crash. CNPG
# protège en plus son primaire d'une éviction gracieuse (PDB dédié)
# pour forcer un switchover contrôlé : la suppression forcée
# contourne aussi cette protection côté Postgres. `cordon`/`uncordon`
# uniquement, aucun nœud détruit.
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

echo "==> État initial"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide
kubectl get pod jenkins-0 -n ci-cd -o wide

PG_PRIMARY_POD=$(kubectl get cluster.postgresql.cnpg.io isaac-postgres -n apps -o jsonpath='{.status.currentPrimary}')
PG_PRIMARY_NODE=$(kubectl get pod "$PG_PRIMARY_POD" -n apps -o jsonpath='{.spec.nodeName}')
JENKINS_NODE=$(kubectl get pod jenkins-0 -n ci-cd -o jsonpath='{.spec.nodeName}')

# Filet de sécurité : un Ctrl+C ou une erreur en cours de route laissait
# des nœuds cordonnés indéfiniment (constaté en vrai, ça a bloqué
# l'ordonnancement de TOUT le cluster au run suivant). Le trap garantit
# l'uncordon quelle que soit la façon dont le script se termine.
trap 'kubectl uncordon "$PG_PRIMARY_NODE" 2>/dev/null || true; kubectl uncordon "$JENKINS_NODE" 2>/dev/null || true' EXIT

echo
echo "==> Primaire isaac-postgres actuel : $PG_PRIMARY_POD (nœud $PG_PRIMARY_NODE)"
echo "==> Jenkins actuellement sur : $JENKINS_NODE"

echo
echo "==> [1/2] Perte simulée du nœud du primaire isaac-postgres ($PG_PRIMARY_NODE)"
kubectl cordon "$PG_PRIMARY_NODE"
kubectl delete pod "$PG_PRIMARY_POD" -n apps --grace-period=0 --force

echo "==> Surveillance du site pendant la bascule (30 x 2s)"
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 https://isaac.obrypoc.fr/ || echo "000")
    echo "  [$i] isaac.obrypoc.fr -> $CODE"
    sleep 2
done

NEW_PRIMARY=$(kubectl get cluster.postgresql.cnpg.io isaac-postgres -n apps -o jsonpath='{.status.currentPrimary}')
echo
echo "==> Nouveau primaire : $NEW_PRIMARY (promotion automatique CloudNativePG, sans action manuelle)"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide

echo
echo "==> [2/2] Perte simulée du nœud de Jenkins ($JENKINS_NODE)"
kubectl cordon "$JENKINS_NODE"
kubectl delete pod jenkins-0 -n ci-cd --grace-period=0 --force

echo
echo "==> Jenkins redémarre ailleurs, volume Longhorn rattaché depuis sa réplique :"
kubectl wait --for=condition=Ready pod/jenkins-0 -n ci-cd --timeout=300s
kubectl get pod jenkins-0 -n ci-cd -o wide

echo
echo "==> Remise en service des nœuds"
kubectl uncordon "$PG_PRIMARY_NODE"
kubectl uncordon "$JENKINS_NODE"

echo
echo "Les deux composants ont survécu à la perte de leur nœud : isaac-postgres par promotion de réplica, Jenkins par redémarrage sur un volume répliqué."
