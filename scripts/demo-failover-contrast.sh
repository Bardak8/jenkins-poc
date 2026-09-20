#!/usr/bin/env bash
# Scénario vidéo : contraste de résilience entre isaac-postgres
# (CloudNativePG, réplication applicative) et Jenkins (instance unique,
# stockage verrouillé à sa zone). Nécessite ha_enabled=true (3 nœuds,
# un par zone) — voir demo-scratch-build.sh ou demo-ha-on.sh.
# Utilise `kubectl drain` (réversible via uncordon), pas de destruction
# réelle de nœud : le mécanisme de blocage (PersistentVolume verrouillé
# à sa zone) est identique dans les deux cas.
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

echo "==> État initial"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide
kubectl get pod jenkins-0 -n ci-cd -o wide

PG_PRIMARY_POD=$(kubectl get cluster.postgresql.cnpg.io isaac-postgres -n apps -o jsonpath='{.status.currentPrimary}')
PG_PRIMARY_NODE=$(kubectl get pod "$PG_PRIMARY_POD" -n apps -o jsonpath='{.spec.nodeName}')
JENKINS_NODE=$(kubectl get pod jenkins-0 -n ci-cd -o jsonpath='{.spec.nodeName}')

echo
echo "==> Primaire isaac-postgres actuel : $PG_PRIMARY_POD (nœud $PG_PRIMARY_NODE)"
echo "==> Jenkins actuellement sur : $JENKINS_NODE"

echo
echo "==> [1/3] Coupure du nœud du primaire isaac-postgres ($PG_PRIMARY_NODE)"
kubectl cordon "$PG_PRIMARY_NODE"
kubectl drain "$PG_PRIMARY_NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s &
DRAIN_PID=$!

echo "==> Surveillance du site pendant la bascule (30 x 2s)"
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 https://isaac.obrypoc.fr/ || echo "000")
    echo "  [$i] isaac.obrypoc.fr -> $CODE"
    sleep 2
done

wait "$DRAIN_PID" || true

NEW_PRIMARY=$(kubectl get cluster.postgresql.cnpg.io isaac-postgres -n apps -o jsonpath='{.status.currentPrimary}')
echo
echo "==> Nouveau primaire : $NEW_PRIMARY (bascule automatique CloudNativePG, sans action manuelle)"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide

echo
echo "==> [2/3] Coupure du nœud de Jenkins ($JENKINS_NODE), même mécanisme"
kubectl cordon "$JENKINS_NODE"
kubectl drain "$JENKINS_NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s || true

echo
echo "==> Jenkins reste bloqué : le volume (sbs-default) est verrouillé à sa zone, aucun autre nœud de la même zone n'est disponible"
kubectl get pod jenkins-0 -n ci-cd
echo
echo "==> Événement attendu : node affinity conflict"
kubectl get events -n ci-cd --field-selector involvedObject.name=jenkins-0 --sort-by='.lastTimestamp' | tail -5

echo
echo "==> [3/3] Remise en service des deux nœuds"
kubectl uncordon "$PG_PRIMARY_NODE"
kubectl uncordon "$JENKINS_NODE"

echo
echo "==> Jenkins revient sur son nœud d'origine (seul nœud de sa zone) :"
kubectl wait --for=condition=Ready pod/jenkins-0 -n ci-cd --timeout=120s
kubectl get pod jenkins-0 -n ci-cd -o wide

echo
echo "Contraste terminé : isaac-postgres a basculé seul en quelques secondes, Jenkins est resté bloqué jusqu'au retour du nœud."
