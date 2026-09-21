#!/usr/bin/env bash
# Bascule DNS automatique entre le Load Balancer principal (fr-par-1) et
# le Load Balancer de secours (fr-par-2, infra/ingress/ha-loadbalancer.tf)
# si le principal ne répond plus plusieurs fois de suite.
#
# Mode par défaut : dry-run, ne touche jamais l'API OVH, log seulement ce
# qui serait fait. Passer --live pour activer les appels réels.
#
# Identifiants chargés depuis .secrets/dns-failover.env (racine du repo,
# gitignoré). Copier .secrets/dns-failover.env.example et renseigner :
#   OVH_APPLICATION_KEY / OVH_APPLICATION_SECRET / OVH_CONSUMER_KEY
#     Générés sur https://www.ovh.com/auth/api/createToken avec les droits :
#       GET  /domain/zone/obrypoc.fr/record*
#       PUT  /domain/zone/obrypoc.fr/record*
#       POST /domain/zone/obrypoc.fr/refresh
#   SECONDARY_IP : sortie ingress_secondary_ip de infra/ingress/
set -euo pipefail

# Charge les identifiants OVH et SECONDARY_IP depuis un fichier local
# plutôt que des variables d'environnement exportées à la main : celles-ci
# disparaissent à la fermeture du terminal, ce fichier survit. Rangé dans
# .secrets/ à la racine, pas dans scripts/, pour ne pas mélanger code et
# secrets.
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.secrets/dns-failover.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

ZONE="obrypoc.fr"
SUBDOMAINS=("isaac" "grafana")
PRIMARY_IP="212.47.239.30"
CHECK_URL_HOST="isaac.obrypoc.fr"
FAIL_THRESHOLD=3
CHECK_INTERVAL=10
STATE_FILE="/tmp/dns-failover-state"

DRY_RUN=true
[ "${1:-}" = "--live" ] && DRY_RUN=false

OVH_API="https://eu.api.ovh.com/1.0"

ovh_call() {
    local method="$1" path="$2" body="${3:-}"
    local ts sig
    ts=$(curl -s "$OVH_API/auth/time")
    sig="\$1\$"$(printf '%s' "${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${OVH_API}${path}+${body}+${ts}" | sha1sum | cut -d' ' -f1)
    curl -s -X "$method" "$OVH_API$path" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
        -H "X-Ovh-Timestamp: $ts" \
        -H "X-Ovh-Signature: $sig" \
        -H "Content-Type: application/json" \
        ${body:+-d "$body"}
}

switch_dns() {
    local target_ip="$1"
    echo "==> Bascule DNS vers $target_ip"
    for sub in "${SUBDOMAINS[@]}"; do
        if $DRY_RUN; then
            echo "  [DRY-RUN] $sub.$ZONE -> $target_ip (aucun appel API réel)"
            continue
        fi
        record_id=$(ovh_call GET "/domain/zone/$ZONE/record?fieldType=A&subDomain=$sub" | grep -o '[0-9]*' | head -1)
        if [ -z "$record_id" ]; then
            echo "  ERREUR : enregistrement introuvable pour $sub.$ZONE"
            continue
        fi
        ovh_call PUT "/domain/zone/$ZONE/record/$record_id" "{\"target\":\"$target_ip\"}" >/dev/null
        echo "  $sub.$ZONE -> $target_ip (record #$record_id)"
    done
    if ! $DRY_RUN; then
        ovh_call POST "/domain/zone/$ZONE/refresh" >/dev/null
        echo "  Zone rafraîchie."
    fi
}

check_primary() {
    local code
    code=$(curl -sk --max-time 5 --resolve "${CHECK_URL_HOST}:443:${PRIMARY_IP}" \
        "https://${CHECK_URL_HOST}/" -o /dev/null -w "%{http_code}" 2>/dev/null) || true
    echo "${code:-000}"
}

if [ -z "${SECONDARY_IP:-}" ]; then
    echo "SECONDARY_IP non défini. Exporte la sortie ingress_secondary_ip de infra/ingress/ avant de lancer ce script."
    exit 1
fi

echo "=== Surveillance du LB principal ($PRIMARY_IP) ==="
if $DRY_RUN; then
    echo "Mode : DRY-RUN (aucun appel API OVH ne sera fait, passer --live pour l'activer)"
else
    echo "Mode : LIVE (les appels API OVH sont réels)"
fi
echo "Secours : $SECONDARY_IP | Seuil : $FAIL_THRESHOLD échecs consécutifs | Intervalle : ${CHECK_INTERVAL}s"
echo

fail_count=0
current_state=$( [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "primary" )

while true; do
    code=$(check_primary)
    ts=$(date '+%H:%M:%S')

    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
        echo "[$ts] LB principal OK (HTTP $code)"
        fail_count=0
        if [ "$current_state" = "secondary" ]; then
            echo "[$ts] Le principal est de nouveau sain. Bascule retour MANUELLE requise (volontairement pas automatique, pour éviter le flapping)."
        fi
    else
        fail_count=$((fail_count + 1))
        echo "[$ts] LB principal injoignable (HTTP $code), échec $fail_count/$FAIL_THRESHOLD"
        if [ "$fail_count" -ge "$FAIL_THRESHOLD" ] && [ "$current_state" = "primary" ]; then
            echo "[$ts] Seuil atteint : bascule vers le LB de secours."
            switch_dns "$SECONDARY_IP"
            current_state="secondary"
            echo "$current_state" > "$STATE_FILE"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
