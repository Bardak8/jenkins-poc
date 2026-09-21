# Surveillance externe (Uptime Kuma)

Volontairement en dehors de Terraform et du cluster Scaleway : l'intérêt de ce point de contrôle est justement d'être indépendant de l'infra qu'il surveille. Si Prometheus/Alertmanager (dans le cluster) tombent avec le cluster, ils ne peuvent plus alerter sur leur propre panne. Uptime Kuma tourne sur un poste externe (ici, le poste de Maxime), donc il survit à une panne du cluster ou de Scaleway en général.

Limite assumée : ne tourne que quand le poste est allumé. Pas un vrai 24/7, ce qui serait le cas en production sur une infra tierce indépendante.

## Lancer

```bash
cd external-monitoring/uptime-kuma
docker compose up -d
```

Interface sur `http://localhost:3001`. Premier lancement : créer le compte admin depuis le navigateur.

## Moniteurs à configurer

| Nom | Type | Cible | Codes acceptés | Objet |
|---|---|---|---|---|
| Cluster Kubernetes | HTTP(s) | `https://3e4d2ca8-f349-48e1-a37c-fca928340290.api.k8s.fr-par.scw.cloud:6443` | 200-499 | API du control plane Scaleway. Répond (même en 401/403 sans authentification) tant que le cluster et Scaleway sont en vie. |
| Jenkins | HTTP(s) | `http://jenkins.obrypoc.fr:8080/login` | 200 | Jenkins n'est joignable que via le VPN du relais (`infra/relay/`) : ce moniteur ne fonctionne que si le poste qui héberge Uptime Kuma a son tunnel WireGuard vers le relais actif. Adresse stable, rien à remettre à jour d'une démo à l'autre. |
| Isaac-Api | HTTP(s) | `https://isaac.obrypoc.fr` | 200 | Public, aucune dépendance VPN. IP réservée (`infra/ingress/`), stable même après un destroy/apply de l'ingress. |
| Grafana | HTTP(s) | `http://grafana.obrypoc.fr:3000` | 200-302 | Grafana n'est joignable que via le VPN du relais (`infra/relay/`), même mécanisme que Jenkins : ce moniteur ne fonctionne que si le poste qui héberge Uptime Kuma a son tunnel WireGuard vers le relais actif. |

Le moniteur "Cluster Kubernetes" est le plus important des quatre : il détecte à la fois une panne du cluster et une panne générale Scaleway, sans dépendre d'aucun état applicatif (Jenkins, ingress, etc.).

## Battement de cœur Prometheus (moniteur 5, type "HTTP(s) - Json Query")

Contrairement aux 4 moniteurs ci-dessus, celui-ci ne vérifie pas qu'un service répond, mais que la chaîne de collecte elle-même est encore vivante : `infra/monitoring/rules/watchdog.yml` fait produire en continu à Prometheus un horodatage (`jenkins_poc_watchdog_heartbeat_timestamp_seconds = time()`). Si ce chiffre cesse d'avancer, Prometheus a un problème même si le pod tourne encore (blocage interne, disque plein, etc.) : un simple ping HTTP 200 sur Grafana ne le détecterait pas, puisque Grafana peut très bien répondre pendant que sa donnée est figée.

C'est délibérément Uptime Kuma qui porte cette vérification, pas Grafana lui-même : Grafana et ce Prometheus vivent sur le même cluster, donc une alerte hébergée dans Grafana mourrait avec la panne qu'elle est censée détecter. Uptime Kuma, externe, reste le seul point réellement indépendant du système qu'il observe.

| Champ | Valeur |
|---|---|
| URL | `http://10.10.40.2:9090/api/v1/query?query=time()-jenkins_poc_watchdog_heartbeat_timestamp_seconds` |
| Json Query Expression | `$.data.result[0].value[1]` |
| Condition | `<` (inférieur à) |
| Valeur attendue | `90` (3x l'intervalle d'évaluation de 30s, marge contre la gigue normale) |

Comme Jenkins et Grafana, uniquement joignable via le VPN du relais (le port 9090 est exposé par `collab-gateway`, `infra/jenkins/collab-gateway.tf`).
