#!/usr/bin/env bash
# Surveillance live pour la démo « accès uniquement par le tunnel ».
# À lancer DEPUIS LE POSTE (pas depuis un pod), dans un watch :
#     watch -n5 bash ~/rapport/jenkins-poc/scripts/watch-vpn.sh
#
# Pendant la démo : couper le tunnel (sudo wg-quick down wg-poc) puis le
# remonter. Les services d'administration deviennent injoignables, le site
# public reste disponible : c'est la preuve du cloisonnement.
#
# wg-poc et pas wg0 : ce poste porte aussi le VPN professionnel, sur une
# interface distincte, pour ne jamais confondre les deux.

WG_IFACE="wg-poc"

# Pas de sudo ici : la simple présence de l'interface suffit, et un watch
# qui redemande un mot de passe toutes les 5 secondes est inutilisable.
if ip link show "$WG_IFACE" >/dev/null 2>&1; then
    echo "TUNNEL $WG_IFACE : ACTIF"
else
    echo "TUNNEL $WG_IFACE : COUPÉ"
fi

echo
printf "%-34s %-12s %s\n" "SERVICE" "ÉTAT" "ACCESSIBLE SANS VPN ?"
printf -- "------------------------------------------------------------------------\n"

check_http() {
    local label="$1" url="$2" besoin="$3"
    local code
    code=$(curl -sk -o /dev/null -w "%{http_code}" \
             --connect-timeout 2 --max-time 3 "$url" 2>/dev/null || echo "000")
    if [ "$code" = "000" ]; then
        printf "%-34s %-12s %s\n" "$label" "INJOIGNABLE" "$besoin"
    else
        printf "%-34s %-12s %s\n" "$label" "HTTP $code" "$besoin"
    fi
}

check_tcp() {
    local label="$1" host="$2" port="$3" besoin="$4"
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        printf "%-34s %-12s %s\n" "$label" "OUVERT" "$besoin"
    else
        printf "%-34s %-12s %s\n" "$label" "INJOIGNABLE" "$besoin"
    fi
}

check_http "Jenkins (10.10.40.2:8080)"     "http://jenkins.obrypoc.fr:8080/login" "non"
check_http "Grafana (10.10.40.2:3000)"     "http://grafana.obrypoc.fr:3000/"      "non"
check_tcp  "Proxmox LAN (192.168.1.3:8006)" "192.168.1.3" 8006                    "non"
check_http "Site public (isaac.obrypoc.fr)" "https://isaac.obrypoc.fr/"           "OUI"

echo
echo "Les trois premiers ne répondent que par le tunnel. Le dernier est public :"
echo "il doit rester disponible quoi qu'il arrive au VPN."
