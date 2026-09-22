#!/usr/bin/env python3
"""Configuration as code pour Uptime Kuma (external-monitoring/uptime-kuma/).

Crée ou met à jour les moniteurs documentés dans README.md via l'API
Socket.IO brute (le wrapper pip uptime-kuma-api a un bug d'attente
d'événement incompatible avec le serveur 1.23.x, contourné ici).

Usage :
    KUMA_PASSWORD=xxx python3 sync_monitors.py [--url http://localhost:3001] [--username admin]
"""
import argparse
import os
import sys

import socketio

DEFAULT_FIELDS = {
    "retryInterval": 60,
    "resendInterval": 0,
    "maxretries": 1,
    "notificationIDList": {},
    "upsideDown": False,
    "description": None,
    "httpBodyEncoding": "json",
    "parent": None,
    "maxredirects": 10,
    "expiryNotification": False,
    "ignoreTls": False,
    "proxyId": None,
    "method": "GET",
    "body": None,
    "headers": None,
    "authMethod": None,
    "timeout": 48,
    "hostname": None,
    "packetSize": 56,
    "port": None,
    "dns_resolve_server": "1.1.1.1",
    "dns_resolve_type": "A",
    "mqttUsername": "",
    "mqttPassword": "",
    "mqttTopic": "",
    "mqttSuccessMessage": "",
    "databaseConnectionString": None,
    "docker_container": "",
    "docker_host": None,
    "game": None,
    "jsonPath": None,
    "expectedValue": None,
}

MONITORS = [
    {
        "name": "Cluster Kubernetes",
        "type": "http",
        "url": "https://3e4d2ca8-f349-48e1-a37c-fca928340290.api.k8s.fr-par.scw.cloud:6443",
        "interval": 60,
        "accepted_statuscodes": ["200-299", "300-399", "400-499"],
        # Le control plane Kapsule présente un certificat dont la chaîne
        # n'est pas dans le magasin de confiance par défaut : sans ça, la
        # requête échoue avant même d'atteindre l'API (peu importe, ce
        # moniteur teste juste "ça répond", pas l'authenticité du certificat.
        "ignoreTls": True,
    },
    {
        "name": "Jenkins",
        "type": "http",
        "url": "http://jenkins.obrypoc.fr:8080/login",
        "interval": 60,
        "accepted_statuscodes": ["200-299"],
    },
    {
        "name": "Isaac-Api",
        "type": "http",
        "url": "https://isaac.obrypoc.fr",
        "interval": 60,
        "accepted_statuscodes": ["200-299"],
    },
    {
        "name": "Grafana",
        "type": "http",
        "url": "http://grafana.obrypoc.fr:3000",
        "interval": 60,
        "accepted_statuscodes": ["200-299", "300-399"],
    },
    # Pas de moniteur "battement de coeur Prometheus" ici : ce check vit
    # maintenant dans Prometheus/Alertmanager lui-même (alerte
    # WatchdogHeartbeatStale, infra/monitoring/rules/watchdog.yml), qui
    # fédère tous les Prometheus (plusieurs en production réelle) - c'est
    # le rôle naturel de Grafana/Alertmanager, pas d'un outil externe.
    # Uptime Kuma ne couvre que ce que Grafana ne peut pas voir sur
    # lui-même : sa propre disponibilité (moniteur ci-dessus), Jenkins,
    # le tunnel VPN, l'API Scaleway (moniteur "Cluster Kubernetes").
]

# Moniteurs à supprimer s'ils existent encore (config antérieure) :
# leur rôle a été repris ailleurs, cf commentaire ci-dessus.
OBSOLETE_MONITORS = ["Battement de coeur Prometheus"]


def build_payload(spec):
    data = dict(DEFAULT_FIELDS)
    data.update({
        "type": spec["type"],
        "name": spec["name"],
        "url": spec["url"],
        "interval": spec["interval"],
        "accepted_statuscodes": spec["accepted_statuscodes"],
    })
    if "jsonPath" in spec:
        data["jsonPath"] = spec["jsonPath"]
        data["expectedValue"] = spec["expectedValue"]
    if "ignoreTls" in spec:
        data["ignoreTls"] = spec["ignoreTls"]
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://localhost:3001")
    parser.add_argument("--username", default="admin")
    args = parser.parse_args()

    password = os.environ.get("KUMA_PASSWORD")
    if not password:
        print("Exporter KUMA_PASSWORD avant de lancer ce script.", file=sys.stderr)
        sys.exit(1)

    sio = socketio.Client()
    monitor_list = {}

    @sio.on("monitorList")
    def on_monitor_list(data):
        monitor_list.clear()
        monitor_list.update(data)

    sio.connect(f"{args.url}/socket.io/", wait_timeout=10)

    login_result = {}
    sio.emit("login", {"username": args.username, "password": password, "token": ""},
              callback=lambda d: login_result.update(d))
    sio.sleep(2)
    if not login_result.get("ok"):
        print("Login échoué :", login_result.get("msg"), file=sys.stderr)
        sio.disconnect()
        sys.exit(1)
    print("Connecté en tant que", args.username)
    sio.sleep(1)  # laisser le temps au monitorList initial d'arriver

    by_name = {m.get("name"): mid for mid, m in monitor_list.items()}

    for spec in MONITORS:
        payload = build_payload(spec)
        existing_id = by_name.get(spec["name"])
        if existing_id:
            payload["id"] = int(existing_id)
            result = {}
            sio.emit("editMonitor", payload, callback=lambda d: result.update(d))
            sio.sleep(2)
            status = "MAJ" if result.get("ok") else f"ERREUR: {result}"
            print(f"[{status}] {spec['name']} (id={existing_id})")
        else:
            result = {}
            sio.emit("add", payload, callback=lambda d: result.update(d))
            sio.sleep(2)
            status = "CREE" if result.get("ok") else f"ERREUR: {result}"
            print(f"[{status}] {spec['name']}")

    for name in OBSOLETE_MONITORS:
        existing_id = by_name.get(name)
        if existing_id:
            result = {}
            sio.emit("deleteMonitor", int(existing_id), callback=lambda d: result.update(d))
            sio.sleep(2)
            status = "SUPPRIME" if result.get("ok") else f"ERREUR: {result}"
            print(f"[{status}] {name} (id={existing_id})")

    sio.disconnect()


if __name__ == "__main__":
    main()
