#!/bin/sh
# Image dédiée pour les passerelles WireGuard du PoC (gateway.tf,
# collab-gateway.tf) : remplace l'ancien pattern alpine:3.20 +
# provisioning inline dans le manifest, qui reproduisait exactement le
# problème identifié chez Peopulse (manifest monolithique, sans image
# dédiée ni chaîne de build) sur les deux gateways du PoC lui-même.
#
# SOCAT_RULES : une règle socat par ligne, "LISTEN-SPEC TARGET-SPEC"
# (les deux arguments passés tels quels à socat), ex :
#   TCP-LISTEN:8006,fork,reuseaddr TCP:192.168.1.3:8006
set -eu

mkdir -p /etc/wireguard
cp /etc/wireguard-secret/wg0.conf /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf
wg-quick up wg0

if [ -n "${SOCAT_RULES:-}" ]; then
  echo "$SOCAT_RULES" | while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    # shellcheck disable=SC2086
    socat $rule &
  done
fi

tail -f /dev/null
