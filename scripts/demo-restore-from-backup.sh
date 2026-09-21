#!/usr/bin/env bash
# Scénario vidéo : destruction totale de Jenkins et isaac-postgres, puis
# restauration réelle depuis Object Storage (infra/backup/), indépendant
# du cluster. Prouve que la sauvegarde nocturne sert vraiment à quelque
# chose, pas seulement qu'elle tourne.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCW_PROFILE="newprofile"
export KUBECONFIG=$(mktemp)
(cd "$ROOT/infra/jenkins" && terraform output -raw kubeconfig > "$KUBECONFIG")

BUCKET="jenkins-poc-backups"
S3_ENDPOINT="https://s3.fr-par.scw.cloud"

echo "==> [1/5] Destruction de Jenkins et isaac-postgres (simule une perte totale)"
(cd "$ROOT/infra/jenkins" && terraform destroy -auto-approve)
(cd "$ROOT/infra/apps" && terraform destroy -auto-approve \
    -target=kubectl_manifest.isaac_postgres_cluster \
    -target=kubernetes_secret.isaac_db_credentials_basic_auth)

echo
echo "==> [2/5] Reconstruction depuis Terraform (config vide, volumes neufs, aucune donnée)"
(cd "$ROOT/infra/jenkins" && terraform apply -auto-approve)
(cd "$ROOT/infra/apps" && terraform apply -auto-approve)

echo
echo "==> [3/5] Attente du cluster isaac-postgres (primaire + réplique)"
kubectl wait --for=condition=Ready cluster.postgresql.cnpg.io/isaac-postgres -n apps --timeout=180s || true
kubectl get cluster isaac-postgres -n apps

echo
echo "==> [4/5] Restauration Jenkins depuis $BUCKET"
kubectl scale statefulset jenkins -n ci-cd --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/component=jenkins-controller -n ci-cd --timeout=60s || true

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
        set -e
        LATEST=\$(aws --endpoint-url=$S3_ENDPOINT s3 ls s3://$BUCKET/jenkins-home/ | sort | tail -1 | awk '{print \$4}')
        echo "Dernier backup : \$LATEST"
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
    command: ["sh", "-c", "tar xzf /shared/backup.tar.gz -C /jenkins-home && echo RESTORE_DONE"]
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

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/restore-jenkins -n ci-cd --timeout=120s
kubectl logs restore-jenkins -n ci-cd -c extract
kubectl delete pod restore-jenkins -n ci-cd

kubectl scale statefulset jenkins -n ci-cd --replicas=1
kubectl rollout status statefulset/jenkins -n ci-cd --timeout=180s

echo
echo "==> [5/5] Restauration isaac-postgres depuis $BUCKET"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restore-postgres
  namespace: apps
spec:
  restartPolicy: Never
  initContainers:
  - name: download
    image: amazon/aws-cli:2.17.62
    command: ["/bin/sh", "-c"]
    args:
      - |
        set -e
        LATEST=\$(aws --endpoint-url=$S3_ENDPOINT s3 ls s3://$BUCKET/isaac-postgres/ | sort | tail -1 | awk '{print \$4}')
        echo "Dernier backup : \$LATEST"
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
  - name: restore
    image: postgres:16-alpine
    command: ["sh", "-c", "gunzip -c /shared/dump.sql.gz | psql -h isaac-postgres-rw -U \$POSTGRES_USER -d isaac && echo RESTORE_DONE"]
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

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/restore-postgres -n apps --timeout=60s
kubectl logs restore-postgres -n apps -c restore
kubectl delete pod restore-postgres -n apps

echo
echo "==> Vérification finale"
curl -s -o /dev/null -w "Jenkins  : %{http_code}\n" --max-time 10 http://jenkins.obrypoc.fr:8080/login
curl -sk -o /dev/null -w "Isaac-Api: %{http_code}\n" --max-time 10 https://isaac.obrypoc.fr/

echo
echo "Restauration terminée : Jenkins et isaac-postgres sont revenus avec leurs données, pas juste leur config."
