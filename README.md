# PoC — Migration Jenkins en infra-as-code

Support de démonstration pour l'oral du Bloc 5 (RNCP Expert en architecture des Systèmes d'Information), lié au dossier Bloc 3 (Annexe G).

## Structure

| Dossier | Rôle |
|---|---|
| `infra/cluster/` | Pool(s) de nœuds Kapsule. `ha_enabled=true` ajoute 2 pools multi-zone (`fr-par-1`, `fr-par-3`) en plus du pool existant (`fr-par-2`) |
| `infra/state-backend/` | Bucket S3 + clé IAM pour le state distant du module `demo/` |
| `infra/jenkins/` | Cluster Kapsule (référencé) + Jenkins (Helm/JCasC/Job DSL) + passerelle WireGuard (automatisation + accès collaborateur) |
| `infra/monitoring/` | kube-prometheus-stack (Prometheus/Alertmanager/Grafana) + alerting mail (Scaleway Transactional Email) |
| `infra/apps/` | Namespace `apps`, registre de conteneurs, cluster Postgres (CloudNativePG), app de démo Isaac-Api |
| `infra/backup/` | Bucket Object Storage + CronJobs de sauvegarde nocturne (home Jenkins, dump Postgres), indépendant du cluster |
| `infra/ingress/` | ingress-nginx + cert-manager, IP publique stable, partagée par Isaac-Api et Grafana |
| `infra/relay/` | VPS Scaleway faisant office de rebond réseau unique pour tout accès humain (Jenkins, Proxmox) |
| `target-infra/vms/outillage/` | VM `outillage` (tunnel WireGuard, bootstrap manuel) |
| `target-infra/vms/demo/` | VM(s) `demo` (créées par Jenkins, state séparé) |
| `deploy/Jenkinsfile.provision` | Pipeline `provision-demo-vm` (Terraform, menus réactifs ROLE/TARGET) |
| `deploy/Jenkinsfile.monitoring` | Pipeline `deploy-monitoring` (lint + tests + déploiement d'une stack Prometheus sur demo-0) |
| `deploy/monitoring-stack/` | Stack Prometheus/Alertmanager/node-exporter/pve-exporter/blackbox-exporter déployée sur `demo-0` |
| `deploy/Jenkinsfile.app` | Pipeline `deploy-app` (détecte les VM app en direct, menu de choix en cours de run) |
| `deploy/app/` | `docker-compose.yml` + `index.html` de l'appli de démo |
| `external-monitoring/uptime-kuma/` | Surveillance externe, volontairement hors Terraform (voir plus bas) |
| `scripts/` | Scripts d'orchestration pour la démo (voir son propre README) |
| `wireguard/` | Clés WireGuard (gitignorées) |

`infra/state-backend/`, `infra/jenkins/` et `infra/monitoring/` ont chacun leur propre state Terraform, volontairement séparés : `state-backend/` ne dépend de rien et ne doit jamais être affecté par un test de reconstruction de Jenkins.

`provision-demo-vm` s'utilise via trois paramètres : `ROLE` (`monitoring` ou `app`), `TARGET` (`1` à `4`, ignoré si `ROLE=monitoring` qui cible toujours `demo-0`), et `REPLACE` qui détruit et recrée la VM ciblée au lieu de simplement s'assurer qu'elle existe.

`deploy-app` détecte en direct les VM app disponibles (ping sur `192.168.1.6`-`.9`) et propose un choix uniquement parmi celles qui répondent, en cours d'exécution du pipeline.

## Prérequis

Projet Scaleway, cluster Kapsule, VPS OVH + Proxmox + pfSense créés manuellement (hors Terraform).

Pour tout monter d'un coup dans le bon ordre : `scripts/demo-up.sh`. Le détail module par module ci-dessous reste valable pour comprendre ou intervenir manuellement.

Pour chaque module (`infra/cluster/`, `infra/state-backend/`, `infra/jenkins/`, `infra/monitoring/`, `infra/apps/`, `infra/backup/`, `infra/ingress/`, `infra/relay/`, `target-infra/vms/outillage/`) :

```bash
terraform init
terraform plan
SCW_PROFILE=newprofile terraform apply
```

## Réseau

- pfSense : WAN `51.161.144.5/32` (MAC virtuelle OVH), gateway `139.99.130.72`. LAN `192.168.1.1/24`, DHCP `.100`-`.199`.
- Proxmox a une deuxième IP sur le bridge LAN (`192.168.1.3` sur `vmbr1`), en plus de son IP publique. Son pare-feu (Datacenter > Firewall) bloque le port 8006 pour tout le monde sauf trois réseaux : `192.168.1.0/24`, `10.10.10.0/24`, `10.10.20.0/24`.
- Deux tunnels WireGuard permanents, chacun sur un point d'entrée différent (séparation automatisation / accès humain) :
  - **`outillage`** (port WAN 51820, forwardé par pfSense) : passerelle du cluster Scaleway (`10.10.10.2`, permanent) et pipeline de déploiement (`10.10.10.3`, éphémère).
  - **pfSense lui-même** (port WAN 51821, WireGuard natif pfSense, interface `VPN_COLLAB`) : accès "collaborateur" (`10.10.20.2`, permanent).
- Chaque tunnel arrive sur un hôte différent, donc Proxmox a besoin d'une route statique par tunnel pour renvoyer ses réponses : `10.10.10.0/24 via 192.168.1.2` (outillage) et `10.10.20.0/24 via 192.168.1.1` (pfSense), ajoutées dans `/etc/network/interfaces` (`post-up ip route add ...` sur `vmbr1`).
- pfSense a l'option **"Bypass firewall rules for traffic on the same interface"** activée (System > Advanced > Firewall & NAT), nécessaire pour que le trafic TCP relayé par `outillage` (entrée et sortie sur la même interface LAN de pfSense) ne soit pas bloqué par le suivi d'état.
- VM(s) démo en IP statique à partir de `192.168.1.5` : `demo-0` (`.5`) porte le monitoring, `demo-1`+ (`.6`, `.7`, ...) portent l'appli de démo.
- **Accès humain via `infra/relay/`** : le poste de Maxime ne se connecte plus directement à `VPN_COLLAB`. Il rejoint un VPS Scaleway dédié (le "rebond") via son propre tunnel WireGuard, et c'est ce rebond qui porte la connexion `VPN_COLLAB` vers pfSense (réutilise la paire de clés "collaborateur" existante) ainsi qu'un tunnel séparé vers un pod `collab-gateway` dans le cluster pour Jenkins. Toute la supervision humaine (Jenkins, Proxmox) passe donc par un seul et même rebond, jamais directement depuis le poste de Maxime.

## Matrice de flux

| Source | Destination | Port/Proto | Objet | État |
|---|---|---|---|---|
| Internet | pfSense WAN `51.161.144.5` | UDP/51820 | Entrée WireGuard `outillage`, forwardé vers `192.168.1.2` | Existant |
| Internet | pfSense WAN `51.161.144.5` | UDP/51821 | Entrée WireGuard `VPN_COLLAB`, terminée sur pfSense | Existant |
| Internet | Proxmox `139.99.130.72` | TCP/8006 | API/WebUI Proxmox | Bloqué (pare-feu Proxmox) |
| gateway pod (`10.10.10.2`) | LAN `192.168.1.0/24` | tout | Tunnel permanent, relais socat (Proxmox, node_exporter) | Existant |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-0` (`192.168.1.5`) | TCP/22 | SSH, déploiement de la stack monitoring (`deploy-monitoring`) | Existant |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-1..4` (`192.168.1.6-9`) | TCP/22 | SSH, install Traefik+site (`deploy-app`) | Existant |
| Pod `provision-demo-vm` (Terraform, cluster) | Service `gateway.ci-cd.svc.cluster.local` | TCP/8006 | API Proxmox via relais socat, sans tunnel dédié | Existant |
| `infra/monitoring` (Prometheus) | Service `gateway.ci-cd.svc.cluster.local` | TCP/9100 | Scrape node_exporter de `demo-0` via relais socat | Existant |
| Jenkins (tous pipelines) | `github.com` | TCP/443 | Checkout du repo (Jenkinsfile, seed job) | Existant |
| Pod `provision-demo-vm` | Bucket `jenkins-poc-tfstate` (Scaleway S3) | TCP/443 | State Terraform distant | Existant |
| Poste Maxime | Relais Scaleway (VPS, `infra/relay/`) | UDP | Tunnel WireGuard `wg0`, seul point d'entrée humain | Existant |
| Relais Scaleway | pod `collab-gateway` (cluster, `10.10.40.2`) | UDP | Tunnel `wg1`, relais Jenkins (`http://jenkins.obrypoc.fr:8080`, jamais exposé autrement) | Existant |
| Relais Scaleway | pfSense (`VPN_COLLAB`) | UDP/51821 | Tunnel `wg2`, réutilise la paire de clés "collaborateur" — remplace l'ancienne connexion directe du poste de Maxime | Existant |
| Poste Maxime | API Kubernetes Scaleway | TCP/443 | `kubectl`/Terraform sur tous les modules `infra/` | Existant |
| Internet | Ingress Scaleway (IP réservée, `infra/ingress/`) | TCP/443 | HTTPS public : Isaac-Api (`isaac.obrypoc.fr`) et Grafana (`grafana.obrypoc.fr`) | Existant |
| GitHub (release Isaac-Api) | Relais Scaleway, port 8090 | TCP/8090 | Webhook release → relayé vers `deploy-isaac-app` (seul chemin nginx autorisé : `/generic-webhook-trigger/`) | Existant |
| CronJobs `infra/backup/` (ci-cd, apps) | Bucket `jenkins-poc-backups` (Scaleway S3) | TCP/443 | Sauvegarde nocturne (home Jenkins, dump Postgres), indépendante du cluster | Existant |
| Alertmanager (K8s + stack demo-0) | `smtp.tem.scw.cloud` | TCP/587 | Envoi des alertes mail (Scaleway Transactional Email) | Existant |
| OVH (hors bande) | Console KVM du serveur | - | Accès de secours à l'hôte Proxmox, indépendant du réseau/pare-feu | Existant (filet de sécurité) |
| Poste Maxime (Uptime Kuma) | API Kubernetes Scaleway + Jenkins (LoadBalancer) | TCP/443, TCP/8080 | Surveillance externe, indépendante du cluster surveillé | Existant |

## Test de reconstruction

```bash
cd infra/jenkins
terraform destroy
terraform apply
```

Jenkins revient dans le même état (plugins, JCasC, jobs, mot de passe admin fixé via `jenkins_admin_password`) sans action manuelle. `infra/state-backend/` étant un module séparé, ce destroy/apply ne touche jamais au state du module `demo/`.

**Point important, découvert en conditions réelles (incident, pas un test volontaire)** : un `destroy`/`apply` complet du module `infra/jenkins/` recrée la PVC à vide — la donnée (historique des builds) ne survit pas à la suppression du volume lui-même, seule la configuration (JCasC, jobs, plugins) se reconstruit. Le PVC est un `kubernetes_persistent_volume_claim` géré directement par Terraform (`infra/jenkins/pvc.tf`), pas par Helm : un destroy du module le supprime comme n'importe quelle autre ressource, aucune annotation ne protège contre ça. C'est `infra/backup/` (sauvegarde nocturne indépendante vers Object Storage) qui couvre ce scénario, pas le stockage lui-même — voir plus bas.

## Points ouverts

Domaine d'envoi mail (`mail.obrypoc.fr`, `infra/monitoring/alerting.tf`) créé mais pas encore validé : les enregistrements DNS SPF/DKIM/DMARC/MX (sortie `alerting_dns_records_to_add` du module) doivent être ajoutés manuellement chez le registrar avant que les mails d'alerte partent réellement.

## Redondance du cluster

Le control plane Kapsule est entièrement géré par Scaleway (offre standard, mutualisée) : sa disponibilité ne dépend pas de ce projet, et une offre à control plane dédié impliquerait de recréer le cluster, hors scope pour un PoC. En cas de panne du control plane, les workloads déjà déployés continuent de tourner (propriété de Kubernetes : kubelet ne dépend pas du control plane pour maintenir les conteneurs déjà programmés), mais plus aucune action (déploiement, replanification d'un pod qui crashe) n'est possible tant qu'il n'est pas revenu.

Le vrai levier actionnable est le pool de nœuds (`infra/cluster/`) : par défaut un seul nœud (`fr-par-2`, état d'origine du cluster, importé sans modification). `terraform apply -var="ha_enabled=true"` ajoute deux pools dans `fr-par-1` et `fr-par-3` — 3 nœuds sur les 3 zones de la région, redondance multi-zone plutôt que multi-nœuds dans la même zone, un pool Scaleway étant rattaché à une seule zone. Le type d'instance diffère selon la zone (`dev1_l` en `fr-par-1`/`fr-par-2`, `GP1-XS` en `fr-par-3` qui ne propose pas la famille DEV1 et où `PRO2-XS` s'est heurté à un quota de compte à 0), testé en conditions réelles.

### Stockage applicatif : de Longhorn à SBS + réplication ciblée

Premier essai (Longhorn, désormais retiré) : un volume bloc Scaleway (`sbs-default`) est verrouillé à sa zone de création, donc un pod avec état ne peut pas être replanifié ailleurs même avec 3 nœuds disponibles — testé en conditions réelles, `kubectl drain` a laissé Jenkins bloqué en `Pending` avec l'erreur `didn't match PersistentVolume's node affinity`. Longhorn (réplication de volumes entre les disques locaux des nœuds) a réglé ce point, mais au prix d'un vrai risque opérationnel découvert en conditions réelles : sur un cluster à un seul nœud, les "3 réplicas" Longhorn finissent tous sur le même disque local — détruire ce nœud (resize de pool, remplacement) détruit alors toutes les copies en même temps. Deux incidents réels de ce type sur cette session, dont un avec perte de données confirmée.

Retenu depuis : `sbs-default` directement (volume réseau Scaleway, détaché du nœud), sans couche Longhorn. Un nœud qui meurt ne perd plus les données (le volume se rattache tout seul à un nœud sain), sans le surcoût de réplication ×3 de Longhorn ni son risque de faux sentiment de redondance sur un cluster à un seul nœud. Le compromis assumé : `sbs-default` reste verrouillé à sa zone, donc **une bascule multi-zone automatique n'est plus couverte au niveau du stockage** (Longhorn le faisait). Pour Jenkins, la sauvegarde nocturne vers Object Storage (`infra/backup/`) couvre le scénario "perte totale du volume", pas la continuité de service en direct. Pour isaac-postgres, la réplication est reportée au niveau applicatif : CloudNativePG fait tourner un primaire et une réplique en streaming, avec bascule automatique si le primaire tombe — une résilience réellement continue, contrairement au stockage seul.

Limité à 2 zones sur les 3 disponibles en `fr-par` (pertinent seulement si `ha_enabled=true`) : `fr-par-3` ne propose pas la famille d'instance `DEV1` utilisée ailleurs, et l'alternative disponible (`PRO2-XS`) est bloquée par un quota du compte à 0 (limite de compte Scaleway, pas un choix d'architecture — testé en conditions réelles, `terraform apply` a échoué avec `Quota exceeded on cp_servers_type_PRO2_XS 0/0`).

**Point d'attention découvert en conditions réelles** : détruire directement un nœud qui héberge encore un pod avec état laisse parfois un `VolumeAttachment` Kubernetes orphelin pointant vers le nœud disparu — le pod reste bloqué en `Init` derrière un volume qui attend indéfiniment un détachement qui n'arrivera jamais. Fix : `kubectl delete volumeattachment <nom>` pour purger la référence fantôme, ce qui débloque un rattachement propre sur le nœud restant. Mieux vaut vider le nœud (`kubectl drain`) avant de le décommissionner plutôt que de le détruire directement.

## Surveillance externe

Ni Prometheus ni Alertmanager ne peuvent alerter sur leur propre panne : ils vivent dans le cluster qu'ils surveillent. `external-monitoring/uptime-kuma/` ajoute un point de contrôle volontairement en dehors de Terraform et de Scaleway (sur le poste de Maxime), qui détecte une panne du cluster ou une panne générale Scaleway indépendamment de l'état du reste de la stack — y compris une panne du control plane que la redondance des pools ne couvre pas. Détails et cibles dans son propre README.

## Lien avec le dossier réel (Bloc 1-3)

`deploy/monitoring-stack/` et `deploy/Jenkinsfile.monitoring` reproduisent la structure et le pipeline du dépôt réel `monitoring_blagnac` (supervision du datacenter de Blagnac, documenté dans le Bloc 3) : mêmes étapes (lint des règles via `promtool check rules`, tests unitaires via `promtool test rules`, déploiement conditionnel par SSH via rebond réseau), même choix d'outils (Prometheus, Alertmanager, node-exporter, pve-exporter, blackbox-exporter), même schéma réseau (passerelle avec relais socat + rebond SSH via tunnel).

Sont volontairement omis : le scanner CVE (outil interne complexe, hors scope PoC), le snmp-exporter (pas de cible SNMP dans ce PoC), les webhooks Teams réels et les adresses IP de Peopulse — remplacés par des cibles génériques propres au PoC.

Cette proximité de structure permet une vraie comparaison de performance de pipeline (mêmes étapes, deux infrastructures Jenkins différentes) plutôt qu'un exemple de déploiement générique sans rapport avec le travail réel.

## Incident : verrouillage du pare-feu Proxmox

En activant le pare-feu Proxmox, les règles d'autorisation ajoutées juste avant sont restées décochées (case "On", désactivée par défaut à la création) : le pare-feu s'est activé avec une politique par défaut DROP et aucune règle active, coupant l'accès à l'interface web et au SSH de l'hôte, y compris pour l'administrateur. Restauré via la console KVM du serveur (accès hors bande fourni par OVH, indépendant du réseau du serveur) : `pve-firewall stop` en urgence, puis correction des règles et `pve-firewall start`. Aucune VM ni aucune donnée affectée, seul l'accès à l'hôte Proxmox lui-même a été interrompu.
