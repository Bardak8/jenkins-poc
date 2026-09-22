# Surveillance externe (Uptime Kuma)

Volontairement en dehors de Terraform et du cluster Scaleway : l'intérêt de ce point de contrôle est justement d'être indépendant de l'infra qu'il surveille. Si Prometheus/Alertmanager (dans le cluster) tombent avec le cluster, ils ne peuvent plus alerter sur leur propre panne. Uptime Kuma tourne sur un poste externe (ici, le poste de Maxime), donc il survit à une panne du cluster ou de Scaleway en général.

Choix de poste assumé : héberger ce point de contrôle sur un tiers de confiance dédié et toujours disponible (au lieu du poste de travail de Maxime) est ce qu'impliquerait un vrai déploiement en production.

## Lancer

```bash
cd external-monitoring/uptime-kuma
docker compose up -d
```

Interface sur `http://localhost:3001`. Premier lancement : créer le compte admin depuis le navigateur, puis synchroniser les moniteurs avec le script fourni (voir plus bas) plutôt que de les recréer à la main.

Mot de passe oublié : `docker exec -i uptime-kuma npm run reset-password` est interactif et peut se bloquer selon le terminal utilisé pour lancer `docker exec` ; en cas de blocage, redémarrer le conteneur (`docker restart uptime-kuma`) et réessayer suffit généralement.

## Moniteurs à configurer

| Nom | Type | Cible | Codes acceptés | Objet |
|---|---|---|---|---|
| Cluster Kubernetes | HTTP(s) | `https://3e4d2ca8-f349-48e1-a37c-fca928340290.api.k8s.fr-par.scw.cloud:6443` | 200-499 | API du control plane Scaleway. Répond (même en 401/403 sans authentification) tant que le cluster et Scaleway sont en vie. |
| Jenkins | HTTP(s) | `http://jenkins.obrypoc.fr:8080/login` | 200 | Jenkins n'est joignable que via le VPN du relais (`infra/relay/`) : ce moniteur ne fonctionne que si le poste qui héberge Uptime Kuma a son tunnel WireGuard vers le relais actif. Adresse stable, rien à remettre à jour d'une démo à l'autre. |
| Isaac-Api | HTTP(s) | `https://isaac.obrypoc.fr` | 200 | Public, aucune dépendance VPN. IP réservée (`infra/ingress/`), stable même après un destroy/apply de l'ingress. |
| Grafana | HTTP(s) | `http://grafana.obrypoc.fr:3000` | 200-302 | Grafana n'est joignable que via le VPN du relais (`infra/relay/`), même mécanisme que Jenkins : ce moniteur ne fonctionne que si le poste qui héberge Uptime Kuma a son tunnel WireGuard vers le relais actif. |

Le moniteur "Cluster Kubernetes" est le plus important des quatre : il détecte à la fois une panne du cluster et une panne générale Scaleway, sans dépendre d'aucun état applicatif (Jenkins, ingress, etc.).

## Répartition des rôles avec Grafana

Uptime Kuma ne couvre volontairement que ce que Grafana ne peut pas voir sur lui-même : sa propre disponibilité (Grafana peut très bien être en panne sans que rien à l'intérieur du cluster ne puisse le signaler), Jenkins, le tunnel VPN nécessaire pour les joindre, et l'API Scaleway (en dehors de toute la chaîne d'observabilité, confirme que l'infra cloud elle-même est vivante).

Tout ce qui concerne la vivacité de la chaîne de collecte elle-même — est-ce que Prometheus évalue encore vraiment ses règles, pas juste "le pod répond" — reste dans Grafana/Alertmanager : alerte `WatchdogHeartbeatStale` (`infra/monitoring/rules/watchdog.yml`), basée sur un battement de cœur que Prometheus produit en continu (`jenkins_poc_watchdog_heartbeat_timestamp_seconds = time()`), envoyée par e-mail via Alertmanager (`infra/monitoring/monitoring.tf`, `alerting.tf`). C'est le rôle naturel de Grafana : c'est lui qui fédère les sources Prometheus (plusieurs en production réelle, une par cluster), pas un outil externe générique. Uptime Kuma n'a donc pas de moniteur dédié à ça.

## Configuration as code

`sync_monitors.py` crée ou met à jour les 4 moniteurs ci-dessus en un appel, via l'API Socket.IO d'Uptime Kuma (le wrapper pip `uptime-kuma-api` a un bug d'attente d'événement avec le serveur 1.23.x, contourné en parlant directement le protocole Socket.IO) :

```bash
python3 -m venv .venv && .venv/bin/pip install python-socketio requests
KUMA_PASSWORD=xxx .venv/bin/python3 sync_monitors.py
```

Idempotent : relançable à volonté, met à jour les moniteurs existants (identifiés par leur nom) au lieu de les dupliquer.
