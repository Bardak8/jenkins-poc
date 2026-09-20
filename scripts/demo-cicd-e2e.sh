#!/usr/bin/env bash
# Scénario vidéo : pipeline CI/CD bout-en-bout, déclenché par une vraie
# release GitHub (pas un déclenchement manuel via l'API Jenkins).
# Prérequis : `gh auth login` fait au préalable, et la variable
# JENKINS_ADMIN_PASSWORD exportée (voir infra/jenkins/terraform.tfvars).
set -euo pipefail

REPO="Bardak8/Isaac-Api"
TAG="demo-$(date +%Y%m%d%H%M%S)"
JENKINS_URL="http://jenkins.obrypoc.fr:8080"

if ! command -v gh >/dev/null; then
    echo "gh (GitHub CLI) est requis : https://cli.github.com/"
    exit 1
fi

if [ -z "${JENKINS_ADMIN_PASSWORD:-}" ]; then
    echo "Exporter JENKINS_ADMIN_PASSWORD avant de lancer ce script."
    exit 1
fi

echo "==> [1/4] État du site avant déploiement"
curl -sk https://isaac.obrypoc.fr/ | grep -o '<title>[^<]*</title>' || true

echo
echo "==> [2/4] Publication d'une release GitHub sur $REPO ($TAG)"
gh release create "$TAG" --repo "$REPO" --title "Démo $TAG" \
    --notes "Déclenchement automatique du pipeline Jenkins via webhook" --target main

echo
echo "==> [3/4] Attente du déclenchement du webhook et suivi du build"
sleep 15
for i in $(seq 1 60); do
    RES=$(curl -s --max-time 10 -u admin:"$JENKINS_ADMIN_PASSWORD" \
        "$JENKINS_URL/job/deploy-isaac-app/lastBuild/api/json?tree=number,building,result")
    NUM=$(echo "$RES" | grep -o '"number":[0-9]*' | cut -d: -f2)
    BUILDING=$(echo "$RES" | grep -o '"building":[a-z]*' | cut -d: -f2)
    RESULT=$(echo "$RES" | grep -o '"result":"[A-Z]*"' | cut -d'"' -f4)
    echo "  [$i] build #$NUM building=$BUILDING result=$RESULT"
    [ "$BUILDING" = "false" ] && [ -n "$RESULT" ] && break
    sleep 5
done

echo
echo "==> [4/4] Site après déploiement (nouvelle image, tag $TAG)"
sleep 5
curl -sk https://isaac.obrypoc.fr/ | grep -o '<title>[^<]*</title>' || true

export KUBECONFIG=$(mktemp)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
(cd "$ROOT/infra/jenkins" && SCW_PROFILE=newprofile terraform output -raw kubeconfig > "$KUBECONFIG")
kubectl get deployment isaac-fansite -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

echo
echo "Pipeline terminé : release GitHub -> webhook -> build kaniko -> déploiement, sans action manuelle sur Jenkins."
