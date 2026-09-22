#!/usr/bin/env bash
export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

echo "--- Pods ci-cd ---"
kubectl get pods -n ci-cd 2>&1
echo
echo "--- Pods isaac-postgres ---"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres 2>&1
echo
echo "--- Contenu BDD (table favorites) ---"
kubectl exec pg-client -n apps -- env PGPASSWORD='iDVGumhPi3BGP9KsI3tbocUc' psql -h isaac-postgres-rw -U isaac -d isaac -c "select id, title from favorites;" 2>&1
echo
echo "--- Historique des builds Jenkins (deploy-isaac-app) ---"
kubectl exec jenkins-0 -n ci-cd -c jenkins -- ls /var/jenkins_home/jobs/deploy-isaac-app/builds/ 2>&1
