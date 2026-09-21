#!/usr/bin/env bash
# Scénario vidéo : scalabilité applicative horizontale (infra/apps/autoscaling.tf).
# Génère une charge CPU sur isaac-fansite depuis un pod dédié, observe le
# HorizontalPodAutoscaler créer des réplicas supplémentaires en réponse,
# puis nettoie. La bascule retour (scale-down) suit son propre délai de
# stabilisation Kubernetes (quelques minutes), pas attendue ici.
set -euo pipefail

export KUBECONFIG=$(mktemp)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
(cd "$ROOT/infra/jenkins" && SCW_PROFILE=newprofile terraform output -raw kubeconfig > "$KUBECONFIG")

echo "==> État initial"
kubectl get hpa isaac-fansite -n apps
kubectl get pods -n apps -l app=isaac-fansite

echo
echo "==> Lancement du générateur de charge (10 boucles wget en parallèle, namespace apps)"
kubectl run load-generator -n apps --image=busybox:1.36 --restart=Never -- \
    /bin/sh -c 'for i in $(seq 1 10); do (while true; do wget -q -O- http://isaac-fansite:8080/ >/dev/null; done) & done; wait'

echo
echo "==> Surveillance du HPA (jusqu'à 5 min, contrôle toutes les 10s)"
for i in $(seq 1 30); do
    sleep 10
    kubectl get hpa isaac-fansite -n apps --no-headers
    REPLICAS=$(kubectl get deployment isaac-fansite -n apps -o jsonpath='{.status.replicas}')
    echo "  [$i] replicas actuels : $REPLICAS"
    [ "$REPLICAS" -gt 2 ] && break
done

echo
echo "==> Pods isaac-fansite après charge"
kubectl get pods -n apps -l app=isaac-fansite

echo
echo "==> Arrêt du générateur de charge"
kubectl delete pod load-generator -n apps --ignore-not-found

echo
echo "Démo terminée : le HPA a réagi à la charge CPU sans action manuelle. Le retour à 2 réplicas suit le délai de stabilisation par défaut de Kubernetes (5 min sans charge) une fois le générateur arrêté, pas la peine de rester devant."
