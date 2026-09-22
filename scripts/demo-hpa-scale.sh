#!/usr/bin/env bash
# Scénario vidéo : scalabilité applicative horizontale (infra/apps/autoscaling.tf).
# Génère une charge sur isaac-fansite depuis un pod dans le namespace
# ingress-nginx (seule source autorisée par la NetworkPolicy vers
# isaac-fansite, infra/apps/network-policies.tf), en HTTPS direct contre
# le service interne du contrôleur ingress-nginx. Observe le
# HorizontalPodAutoscaler créer des réplicas supplémentaires, puis
# nettoie.
#
# Pourquoi ce chemin précis, pas un pod générique ni le chemin public :
# - un pod de charge dans le namespace apps est bloqué par la
#   NetworkPolicy, comportement voulu, pas un bug à contourner ;
# - le port 80 de l'ingress redirige en 308 vers HTTPS sans jamais
#   atteindre le pod applicatif (aucune charge réelle générée) ;
# - le chemin public (poste -> Internet -> LB) marche mais sa charge
#   réelle est trop variable (latence/TLS côté client) pour un
#   déclenchement fiable en enregistrement ; en direct dans le cluster,
#   en HTTPS, c'est rapide et reproductible.
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PARALLEL=14
DURATION=180
POD="hpa-load-generator"

echo "==> État initial"
kubectl get hpa isaac-fansite -n apps
kubectl get pods -n apps -l app=isaac-fansite

echo
echo "==> Lancement de la charge ($PARALLEL boucles curl en parallèle, namespace ingress-nginx)"
kubectl run "$POD" -n ingress-nginx --image=curlimages/curl:8.10.1 --restart=Never -- \
    /bin/sh -c "for i in \$(seq 1 $PARALLEL); do (while true; do curl -sk -o /dev/null -H 'Host: isaac.obrypoc.fr' https://ingress-nginx-controller.ingress-nginx.svc.cluster.local:443/; sleep 0.1; done) & done; sleep $DURATION" >/dev/null

cleanup() {
    kubectl delete pod "$POD" -n ingress-nginx --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "==> Surveillance du HPA (jusqu'à ${DURATION}s, contrôle toutes les 10s)"
for i in $(seq 1 $((DURATION / 10))); do
    sleep 10
    kubectl get hpa isaac-fansite -n apps --no-headers
    REPLICAS=$(kubectl get deployment isaac-fansite -n apps -o jsonpath='{.status.replicas}')
    echo "  [$i] replicas actuels : $REPLICAS"
    [ "$REPLICAS" -ge 5 ] && break
done

echo
echo "==> Pods isaac-fansite après charge"
kubectl get pods -n apps -l app=isaac-fansite

echo
echo "==> Arrêt de la charge"
cleanup
trap - EXIT

echo
echo "Démo terminée : le HPA a réagi à la charge sans action manuelle."
