#!/usr/bin/env bash
# Scénario vidéo : preuve que l'accès humain passe bien par le tunnel
# WireGuard du rebond (infra/relay/), pas par une IP publique directe.
# À lancer DEPUIS TON POSTE (pas depuis un pod), tunnel wg0 actif.
set -euo pipefail

section() { echo; echo "==> $1"; }

section "État du tunnel WireGuard local (wg0)"
sudo wg show wg0

section "Résolution DNS"
echo "jenkins.obrypoc.fr -> $(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"
echo "isaac.obrypoc.fr   -> $(getent hosts isaac.obrypoc.fr | awk '{print $1}')"
echo "192.168.1.3 (Proxmox, LAN)"

section "Route utilisée par le système pour chaque destination"
echo "-- Jenkins (doit passer par wg0) --"
ip route get "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"
echo
echo "-- Proxmox LAN (doit passer par wg0) --"
ip route get 192.168.1.3
echo
echo "-- Proxmox IP PUBLIQUE (ne doit PAS passer par wg0 : split-tunnel) --"
ip route get 139.99.130.72

section "Ping Jenkins (via tunnel, wg0)"
ping -c 4 "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"

section "Ping Proxmox LAN (via tunnel, wg0 -> rebond -> pfSense)"
ping -c 4 192.168.1.3

section "Ping Proxmox IP publique (hors tunnel, direct par la box internet)"
ping -c 4 139.99.130.72

section "Traceroute Jenkins (peu de sauts visibles : chiffré dans le tunnel)"
traceroute -n -m 5 "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')" 2>&1 || tracepath "$(getent hosts jenkins.obrypoc.fr | awk '{print $1}')"

section "Traceroute Proxmox IP publique (sort par la box internet, plusieurs sauts avant d'atteindre Scaleway/OVH)"
traceroute -n -m 15 139.99.130.72 2>&1 || tracepath 139.99.130.72

section "Test applicatif final"
curl -s -o /dev/null -w "Jenkins  : %{http_code}\n" --max-time 10 http://jenkins.obrypoc.fr:8080/login
curl -sk -o /dev/null -w "Isaac-Api: %{http_code}\n" --max-time 10 https://isaac.obrypoc.fr/

echo
echo "Résumé : Jenkins et le LAN Proxmox ne sont joignables qu'en passant par wg0 (le rebond) ; l'IP publique de Proxmox emprunte un chemin réseau totalement différent, hors tunnel."
