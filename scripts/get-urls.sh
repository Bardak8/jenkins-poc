#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="$HOME/.kube/kubeconfig-k8s-jenkins-poc.yaml"

wait_for_ip() {
    local svc="$1" ns="$2"
    for _ in $(seq 1 15); do
        ip=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        [ -n "$ip" ] && echo "$ip" && return 0
        sleep 4
    done
    echo "(pas encore assignée)"
}

echo "Jenkins : http://$(wait_for_ip jenkins ci-cd):8080"
echo "Grafana : http://$(wait_for_ip monitoring-grafana monitoring)"
echo
echo "Mot de passe Grafana :"
echo "  kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo
echo "-> À reporter dans Uptime Kuma si l'IP Jenkins a changé (moniteur 'Jenkins')."
