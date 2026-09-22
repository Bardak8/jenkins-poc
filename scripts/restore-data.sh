#!/usr/bin/env bash
# Restauration des données depuis Object Storage, sans rien détruire.
#
# À utiliser après une reconstruction complète (scripts/demo-scratch-build.sh),
# qui remonte la configuration mais repart avec des volumes vides : Jenkins
# sans historique de builds, base applicative sans données. Ce script va
# rechercher la dernière sauvegarde de chaque côté et la réinjecte.
#
# Différence avec demo-restore-from-backup.sh : celui-ci ne détruit rien et
# ne sert pas de démonstration, c'est la procédure de reprise.
set -euo pipefail

export SCW_PROFILE="newprofile"
export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

BUCKET="jenkins-poc-backups"
S3_ENDPOINT="https://s3.fr-par.scw.cloud"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "==> [1/3] Vérification des prérequis"
kubectl get secret backup-credentials -n ci-cd >/dev/null
kubectl get secret backup-credentials -n apps >/dev/null
kubectl rollout status statefulset/jenkins -n ci-cd --timeout=600s
for i in $(seq 1 40); do
    PGREADY=$(kubectl get cluster isaac-postgres -n apps -o jsonpath='{.status.readyInstances}' 2>/dev/null || true)
    log "    isaac-postgres : ${PGREADY:-0}/2 instances prêtes"
    [ "${PGREADY:-0}" = "2" ] && break
    sleep 15
done

log "==> [2/3] Restauration de Jenkins (home complet)"
kubectl scale statefulset jenkins -n ci-cd --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/component=jenkins-controller -n ci-cd --timeout=180s || true
kubectl delete pod restore-jenkins -n ci-cd --ignore-not-found >/dev/null 2>&1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restore-jenkins
  namespace: ci-cd
spec:
  restartPolicy: Never
  initContainers:
  - name: download
    image: amazon/aws-cli:2.17.62
    command: ["/bin/sh", "-c"]
    args:
      - |
        set -eo pipefail
        LATEST=\$(aws --endpoint-url=$S3_ENDPOINT s3 ls s3://$BUCKET/jenkins-home/ | sort | tail -1 | awk '{print \$4}')
        echo "Dernière sauvegarde : \$LATEST"
        aws --endpoint-url=$S3_ENDPOINT s3 cp s3://$BUCKET/jenkins-home/\$LATEST /shared/backup.tar.gz
    envFrom:
    - secretRef:
        name: backup-credentials
    env:
    - name: AWS_DEFAULT_REGION
      value: fr-par
    volumeMounts:
    - name: shared
      mountPath: /shared
  containers:
  - name: extract
    image: alpine:3.20
    command: ["sh", "-c", "set -e; tar xzf /shared/backup.tar.gz -C /jenkins-home && echo RESTORE_DONE"]
    volumeMounts:
    - name: shared
      mountPath: /shared
    - name: jenkins-home
      mountPath: /jenkins-home
  volumes:
  - name: shared
    emptyDir: {}
  - name: jenkins-home
    persistentVolumeClaim:
      claimName: jenkins-sbs
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/restore-jenkins -n ci-cd --timeout=900s
kubectl logs restore-jenkins -n ci-cd -c extract
kubectl delete pod restore-jenkins -n ci-cd >/dev/null
kubectl scale statefulset jenkins -n ci-cd --replicas=1
kubectl rollout status statefulset/jenkins -n ci-cd --timeout=600s

log "==> [3/3] Restauration de la base applicative"
kubectl delete pod restore-postgres -n apps --ignore-not-found >/dev/null 2>&1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restore-postgres
  namespace: apps
  labels:
    role: db-admin-access
spec:
  restartPolicy: Never
  initContainers:
  - name: download
    image: amazon/aws-cli:2.17.62
    command: ["/bin/sh", "-c"]
    args:
      - |
        set -eo pipefail
        LATEST=\$(aws --endpoint-url=$S3_ENDPOINT s3 ls s3://$BUCKET/isaac-postgres/ | sort | tail -1 | awk '{print \$4}')
        echo "Dernière sauvegarde : \$LATEST"
        aws --endpoint-url=$S3_ENDPOINT s3 cp s3://$BUCKET/isaac-postgres/\$LATEST /shared/dump.sql.gz
    envFrom:
    - secretRef:
        name: backup-credentials
    env:
    - name: AWS_DEFAULT_REGION
      value: fr-par
    volumeMounts:
    - name: shared
      mountPath: /shared
  containers:
  # postgres:18-alpine et pas 16 : pg_dump/psql refusent une version serveur
  # plus récente qu'eux, et le cluster CNPG tourne en 18.x.
  - name: restore
    image: postgres:18-alpine
    command: ["sh", "-c", "gunzip -c /shared/dump.sql.gz | psql -h isaac-postgres-rw -U \$POSTGRES_USER -d isaac; echo RESTORE_DONE"]
    env:
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: isaac-db-credentials
          key: username
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: isaac-db-credentials
          key: password
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/restore-postgres -n apps --timeout=300s
kubectl logs restore-postgres -n apps -c restore | tail -5
kubectl delete pod restore-postgres -n apps >/dev/null

echo
log "==> Vérification"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres \
    -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,ROLE:.metadata.labels.role'
echo -n "  builds Jenkins restaurés : "
kubectl exec jenkins-0 -n ci-cd -c jenkins -- ls /var/jenkins_home/jobs/deploy-isaac-app/builds/ 2>/dev/null | tr '\n' ' ' || echo "(aucun)"
echo
curl -s  -o /dev/null -w "  Jenkins   : %{http_code}\n" --max-time 10 http://jenkins.obrypoc.fr:8080/login || true
curl -sk -o /dev/null -w "  Isaac-Api : %{http_code}\n" --max-time 10 https://isaac.obrypoc.fr/ || true
curl -sk -o /dev/null -w "  Favoris   : %{http_code}\n" --max-time 10 https://isaac.obrypoc.fr/favorites || true

echo
log "Restauration terminée."
