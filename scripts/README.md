# Scripts de démo

Enchaînent les commandes Terraform/kubectl dans le bon ordre pour les scénarios de démo, sans changer l'architecture (les modules restent séparés pour de vraies raisons, voir le README principal).

| Script | Usage |
|---|---|
| `demo-up.sh` | Applique tous les modules dans l'ordre (state-backend, cluster, storage, jenkins, monitoring). Point d'entrée pour tout remonter depuis zéro. |
| `demo-ha-on.sh` | Passe à 3 nœuds multi-zone (`fr-par-1/2/3`). |
| `demo-ha-off.sh` | Repasse à 1 nœud (`fr-par-2`), pour ne pas payer les 2 nœuds en plus entre deux démos. |
| `demo-failover-test.sh` | Rejoue le test de bascule : cordon/drain le nœud de Jenkins, attend la replanification ailleurs, remet le nœud en service. |
| `get-urls.sh` | Affiche les URL actuelles de Jenkins et Grafana (LoadBalancer). |

Toutes les IP de LoadBalancer changent à chaque recréation du service (destroy/apply, ou bascule de type de service). `get-urls.sh` sert justement à les retrouver rapidement — penser à mettre à jour le moniteur "Jenkins" dans Uptime Kuma si l'IP a changé (pas automatisable proprement : Uptime Kuma n'a pas de config as code, tout est dans sa base SQLite via l'UI).
