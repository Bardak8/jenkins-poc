# Scripts de démo

Enchaînent les commandes Terraform/kubectl dans le bon ordre pour les scénarios de démo, sans changer l'architecture (les modules restent séparés pour de vraies raisons, voir le README principal).

| Script | Usage |
|---|---|
| `demo-up.sh` | Applique tous les modules dans l'ordre (state-backend, cluster, jenkins, relay, ingress, apps, monitoring, backup). Point d'entrée pour tout remonter depuis zéro. |
| `demo-ha-on.sh` | Passe à 3 nœuds multi-zone (`fr-par-1/2/3`). |
| `demo-ha-off.sh` | Repasse à 1 nœud (`fr-par-2`), pour ne pas payer les 2 nœuds en plus entre deux démos. |
| `get-urls.sh` | Affiche les URL d'accès à Jenkins, Grafana et Isaac-Api. |
| `dns-failover.sh` | Surveille le Load Balancer principal (fr-par-1) et bascule le DNS OVH vers le LB de secours (fr-par-2, `infra/ingress/ha-loadbalancer.tf`) après 3 échecs consécutifs. Mode dry-run par défaut, `--live` pour les appels réels. Identifiants dans `.secrets/dns-failover.env` (voir `.secrets/dns-failover.env.example`). |

## Scénarios pour l'enregistrement de l'oral

| Script | Usage |
|---|---|
| `demo-scratch-build.sh` | Destruction complète (hors `state-backend`) puis reconstruction, cluster à 3 nœuds multi-zone dès le premier `apply` (`ha_enabled=true` d'emblée, pas de montée en charge progressive). |
| `demo-restore-from-backup.sh` | Détruit Jenkins et isaac-postgres, les reconstruit à vide via Terraform, puis restaure les vraies données depuis le bucket Object Storage (`infra/backup/`) — home Jenkins et dump Postgres. |
| `demo-failover-contrast.sh` | Coupe (drain) le nœud du primaire isaac-postgres : bascule automatique CloudNativePG en quelques secondes. Coupe ensuite le nœud de Jenkins : reste bloqué (volume verrouillé à sa zone). Nécessite `ha_enabled=true` (3 nœuds, un par zone), donc à lancer après `demo-scratch-build.sh` ou `demo-ha-on.sh`. |
| `demo-hpa-scale.sh` | Génère une charge CPU sur isaac-fansite (pod de charge dédié), observe le HorizontalPodAutoscaler (`infra/apps/autoscaling.tf`) créer des réplicas supplémentaires sans action manuelle, puis nettoie. |
| `demo-cicd-e2e.sh` | Publie une vraie release GitHub sur Isaac-Api, suit le déclenchement du webhook et le build Jenkins, vérifie que le site est à jour. Nécessite `gh auth login` et `JENKINS_ADMIN_PASSWORD` exporté. |
| `demo-vpn-check.sh` | **À lancer depuis le poste de Maxime**, pas un pod : ping/traceroute/`ip route get` vers Jenkins, Grafana et le LAN Proxmox (via le tunnel `wg0`) contre l'IP publique de Proxmox (hors tunnel), pour prouver visuellement que l'accès humain passe bien par le rebond. |

Jenkins et Grafana (VPN uniquement, même tunnel `collab-gateway`) et Isaac-Api (public) ont chacun une adresse stable (tunnel WireGuard fixe pour les deux premiers, IP publique réservée pour l'ingress d'Isaac-Api) : elle ne change pas d'un destroy/apply à l'autre, rien à mettre à jour dans Uptime Kuma.

Supprimé de ce dossier : `demo-failover-test.sh`, redondant avec `demo-failover-contrast.sh` et devenu invalide depuis le retrait de Longhorn (le volume Jenkins verrouillé à sa zone empêche la replanification qu'il testait, comportement désormais couvert par `demo-failover-contrast.sh`).
