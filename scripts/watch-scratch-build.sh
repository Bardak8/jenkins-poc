#!/usr/bin/env bash
export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

echo "--- Noeuds (zone) ---"
kubectl get nodes --no-headers -L topology.kubernetes.io/zone 2>&1 \
  | awk '{print $1"  "$2"  "$6}' || true

echo
echo "--- Pods par namespace ---"
kubectl get pods -A --no-headers 2>/dev/null \
  | awk '
      $1 ~ /^(ci-cd|apps|monitoring|ingress-nginx|longhorn-system)$/ {
        total[$1]++; if ($4 == "Running") running[$1]++
      }
      END {
        split("ci-cd apps monitoring ingress-nginx longhorn-system", order, " ")
        for (i = 1; i <= 5; i++) {
          ns = order[i]
          printf "  %-16s %s pods (%s Running)\n", ns, total[ns] + 0, running[ns] + 0
        }
      }'

echo
echo "--- Postgres (doivent finir sur 2 noeuds differents) ---"
kubectl get pods -n apps -l cnpg.io/cluster=isaac-postgres --no-headers \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,ROLE:.metadata.labels.role' 2>&1 \
  | sed 's/^/  /' || true

echo
echo "--- Endpoints HTTP ---"
check_url() {
  local label="$1" url="$2"
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 1 --max-time 2 "$url" 2>/dev/null || echo "000")
  if [ "$code" = "000" ]; then
    printf "  %-12s INJOIGNABLE\n" "$label"
  else
    printf "  %-12s HTTP %s\n" "$label" "$code"
  fi
}
check_url "Isaac-Api" "https://isaac.obrypoc.fr/"
check_url "Jenkins" "http://jenkins.obrypoc.fr:8080/login"
check_url "Grafana" "http://grafana.obrypoc.fr:3000/"
