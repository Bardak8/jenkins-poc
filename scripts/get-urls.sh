#!/usr/bin/env bash
set -euo pipefail

echo "Jenkins : http://jenkins.obrypoc.fr:8080 (uniquement via le VPN du relais, infra/relay/)"
echo "Grafana : http://grafana.obrypoc.fr:3000 (uniquement via le VPN du relais, comme Jenkins)"
echo "Isaac-Api : https://isaac.obrypoc.fr (public)"
echo
echo "Mot de passe Grafana :"
echo "  kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo
echo "Les trois URL sont stables (tunnel WireGuard fixe pour Jenkins et Grafana, IP publique réservée pour Isaac-Api) : rien à mettre à jour dans Uptime Kuma après un destroy/apply."
