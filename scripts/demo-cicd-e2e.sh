#!/usr/bin/env bash
# Scénario vidéo : pipeline CI/CD bout-en-bout, déclenché par une vraie
# release GitHub (pas un déclenchement manuel via l'API Jenkins).
# Prérequis : GH_TOKEN exporté (personal access token à portée
# restreinte, "Only select repositories" -> Bardak8/Isaac-Api
# uniquement, permission "Contents: Read and write" -- jamais un token
# large sur tout le compte), et JENKINS_ADMIN_PASSWORD exporté (voir
# infra/jenkins/terraform.tfvars). Appel direct à l'API REST GitHub en
# curl, pas de dépendance à gh CLI.
set -euo pipefail

REPO="Bardak8/Isaac-Api"
TAG="demo-$(date +%Y%m%d%H%M%S)"
JENKINS_URL="http://jenkins.obrypoc.fr:8080"

if [ -z "${GH_TOKEN:-}" ]; then
    echo "Exporter GH_TOKEN (personal access token restreint à $REPO) avant de lancer ce script."
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
HTTP_CODE=$(curl -s -o /tmp/gh-release-response.json -w "%{http_code}" \
    -X POST "https://api.github.com/repos/$REPO/releases" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "{\"tag_name\":\"$TAG\",\"target_commitish\":\"main\",\"name\":\"Démo $TAG\",\"body\":\"Déclenchement automatique du pipeline Jenkins via webhook\"}")
if [ "$HTTP_CODE" != "201" ]; then
    echo "Échec création release (HTTP $HTTP_CODE) :"
    cat /tmp/gh-release-response.json
    exit 1
fi
echo "Release $TAG créée."

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

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"
kubectl get deployment isaac-fansite -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

echo
echo "Pipeline terminé : release GitHub -> webhook -> build kaniko -> déploiement, sans action manuelle sur Jenkins."
