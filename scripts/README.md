# Scripts de démo

Enchaînent les commandes Terraform/kubectl dans le bon ordre pour les scénarios de démo, sans changer l'architecture (les modules restent séparés pour de vraies raisons, voir le README principal).

| Script | Usage |
|---|---|
| `demo-up.sh` | Applique tous les modules dans l'ordre (state-backend, cluster, jenkins, relay, ingress, apps, monitoring, backup). Point d'entrée pour tout remonter depuis zéro. |
| `demo-ha-on.sh` | Passe à 3 nœuds multi-zone (`fr-par-1/2/3`). |
| `demo-ha-off.sh` | Repasse à 1 nœud (`fr-par-2`), pour ne pas payer les 2 nœuds en plus entre deux démos. |
| `demo-failover-test.sh` | Rejoue le test de bascule : cordon/drain le nœud de Jenkins, attend la replanification ailleurs, remet le nœud en service. Ne fonctionne que si un nœud de repli existe dans la même zone (voir README principal, section stockage). |
| `get-urls.sh` | Affiche les URL d'accès à Jenkins, Grafana et Isaac-Api. |

Jenkins (VPN uniquement), Grafana et Isaac-Api ont chacun une adresse stable (tunnel WireGuard fixe pour Jenkins, IP publique réservée pour l'ingress partagé de Grafana/Isaac-Api) : elle ne change pas d'un destroy/apply à l'autre, rien à mettre à jour dans Uptime Kuma.
