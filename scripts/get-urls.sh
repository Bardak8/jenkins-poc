#!/usr/bin/env bash
set -euo pipefail

echo "Jenkins : http://jenkins.obrypoc.fr:8080 (uniquement via le VPN du relais, infra/relay/)"
echo "Grafana : https://grafana.obrypoc.fr"
echo "Isaac-Api : https://isaac.obrypoc.fr"
echo
echo "Mot de passe Grafana :"
echo "  kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo
echo "Les trois URL sont stables (IP publique réservée pour Grafana/Isaac-Api, tunnel WireGuard fixe pour Jenkins) : rien à mettre à jour dans Uptime Kuma après un destroy/apply."
