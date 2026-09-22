#!/usr/bin/env bash
# Scénario vidéo : preuve que l'accès humain passe bien par le tunnel
# WireGuard du rebond (infra/relay/), pas par une IP publique directe.
# À lancer DEPUIS TON POSTE (pas depuis un pod), interface wg-poc active.
#
# wg-poc, pas wg0 : ce poste a aussi le VPN pro (branché sur wg0 selon
# l'ordre de connexion), volontairement sur une interface distincte du
# tunnel PoC pour ne jamais les confondre.
set -euo pipefail

WG_IFACE="wg-poc"

section() { echo; echo "==> $1"; }

section "État du tunnel WireGuard local ($WG_IFACE)"
sudo wg show "$WG_IFACE"

section "Résolution DNS"
echo "jenkins.obrypoc.fr -> $(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"
echo "grafana.obrypoc.fr -> $(getent hosts grafana.obrypoc.fr | awk '{print $1}')"
echo "isaac.obrypoc.fr   -> $(getent hosts isaac.obrypoc.fr | awk '{print $1}')"
echo "192.168.1.3 (Proxmox, LAN)"

section "Route utilisée par le système pour chaque destination"
echo "-- Jenkins (doit passer par wg-poc) --"
ip route get "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"
echo
echo "-- Grafana (doit passer par wg-poc, même tunnel que Jenkins) --"
ip route get "$(getent hosts grafana.obrypoc.fr | awk '{print $1}')"
echo
echo "-- Proxmox LAN (doit passer par wg-poc) --"
ip route get 192.168.1.3
echo
echo "-- Proxmox IP PUBLIQUE (ne doit PAS passer par wg-poc : split-tunnel) --"
ip route get 139.99.130.72

section "Ping Jenkins (via tunnel, wg-poc)"
ping -c 4 "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')" || true

section "Ping Grafana (via tunnel, wg-poc)"
ping -c 4 "$(getent hosts grafana.obrypoc.fr | awk '{print $1}')" || true

section "Proxmox LAN, via tunnel wg-poc -> rebond -> pfSense (ICMP filtré côté pfSense, test TCP à la place)"
if timeout 3 bash -c "cat < /dev/null > /dev/tcp/192.168.1.3/8006" 2>/dev/null; then
    echo "192.168.1.3:8006 (interface web Proxmox) joignable via le tunnel"
else
    echo "192.168.1.3:8006 injoignable"
fi

section "Ping Proxmox IP publique (hors tunnel, direct par la box internet)"
ping -c 4 139.99.130.72 || true

TRACE="tracepath"
command -v traceroute >/dev/null 2>&1 && TRACE="traceroute -n"

section "Traceroute Jenkins (peu de sauts visibles : chiffré dans le tunnel)"
$TRACE "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')" 2>&1 || true

section "Traceroute Proxmox IP publique (sort par la box internet, plusieurs sauts avant d'atteindre Scaleway/OVH)"
$TRACE 139.99.130.72 2>&1 || true

section "Test applicatif final"
curl -s -o /dev/null -w "Jenkins  : %{http_code}\n" --max-time 10 http://jenkins.obrypoc.fr:8080/login
curl -s -o /dev/null -w "Grafana  : %{http_code}\n" --max-time 10 http://grafana.obrypoc.fr:3000/
curl -sk -o /dev/null -w "Isaac-Api: %{http_code}\n" --max-time 10 https://isaac.obrypoc.fr/

echo
echo "Résumé : Jenkins, Grafana et le LAN Proxmox ne sont joignables qu'en passant par wg-poc (le rebond) ; l'IP publique de Proxmox emprunte un chemin réseau totalement différent, hors tunnel."
