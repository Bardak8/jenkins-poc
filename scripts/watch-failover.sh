#!/usr/bin/env bash
export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

{
  paste <(kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o wide --no-headers | awk 'BEGIN{print "NAME\tREADY\tSTATUS\tAGE\tNODE"} {print $1"\t"$2"\t"$3"\t"$5"\t"$7}') \
        <(kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres -o custom-columns='ROLE:.metadata.labels.role')
  echo
  kubectl get pod jenkins-0 -n ci-cd -o wide --no-headers | awk 'BEGIN{print "NAME\tREADY\tSTATUS\tAGE\tNODE"} {print $1"\t"$2"\t"$3"\t"$5"\t"$7}'
} | column -t

echo
echo "--- BDD ---"
kubectl exec -n apps pg-client -- env PGPASSWORD='iDVGumhPi3BGP9KsI3tbocUc' psql -U isaac -h isaac-postgres-rw -d isaac -c "select id, title from favorites;"
