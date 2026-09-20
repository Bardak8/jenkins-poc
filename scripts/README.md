# Scripts de démo

Enchaînent les commandes Terraform/kubectl dans le bon ordre pour les scénarios de démo, sans changer l'architecture (les modules restent séparés pour de vraies raisons, voir le README principal).

| Script | Usage |
|---|---|
| `demo-up.sh` | Applique tous les modules dans l'ordre (state-backend, cluster, jenkins, relay, ingress, apps, monitoring, backup). Point d'entrée pour tout remonter depuis zéro. |
| `demo-ha-on.sh` | Passe à 3 nœuds multi-zone (`fr-par-1/2/3`). |
| `demo-ha-off.sh` | Repasse à 1 nœud (`fr-par-2`), pour ne pas payer les 2 nœuds en plus entre deux démos. |
| `demo-failover-test.sh` | Rejoue le test de bascule : cordon/drain le nœud de Jenkins, attend la replanification ailleurs, remet le nœud en service. Ne fonctionne que si un nœud de repli existe dans la même zone (voir README principal, section stockage). |
| `get-urls.sh` | Affiche les URL d'accès à Jenkins, Grafana et Isaac-Api. |

## Scénarios pour l'enregistrement de l'oral

| Script | Usage |
|---|---|
| `demo-scratch-build.sh` | Destruction complète (hors `state-backend`) puis reconstruction, cluster à 3 nœuds multi-zone dès le premier `apply` (`ha_enabled=true` d'emblée, pas de montée en charge progressive). |
| `demo-restore-from-backup.sh` | Détruit Jenkins et isaac-postgres, les reconstruit à vide via Terraform, puis restaure les vraies données depuis le bucket Object Storage (`infra/backup/`) — home Jenkins et dump Postgres. |
| `demo-failover-contrast.sh` | Coupe (drain) le nœud du primaire isaac-postgres : bascule automatique CloudNativePG en quelques secondes. Coupe ensuite le nœud de Jenkins : reste bloqué (volume verrouillé à sa zone). Nécessite `ha_enabled=true` (3 nœuds, un par zone), donc à lancer après `demo-scratch-build.sh` ou `demo-ha-on.sh`. |
| `demo-cicd-e2e.sh` | Publie une vraie release GitHub sur Isaac-Api, suit le déclenchement du webhook et le build Jenkins, vérifie que le site est à jour. Nécessite `gh auth login` et `JENKINS_ADMIN_PASSWORD` exporté. |
| `demo-vpn-check.sh` | **À lancer depuis le poste de Maxime**, pas un pod : ping/traceroute/`ip route get` vers Jenkins et le LAN Proxmox (via le tunnel `wg0`) contre l'IP publique de Proxmox (hors tunnel), pour prouver visuellement que l'accès humain passe bien par le rebond. |

Jenkins (VPN uniquement), Grafana et Isaac-Api ont chacun une adresse stable (tunnel WireGuard fixe pour Jenkins, IP publique réservée pour l'ingress partagé de Grafana/Isaac-Api) : elle ne change pas d'un destroy/apply à l'autre, rien à mettre à jour dans Uptime Kuma.
