# PoC — Migration Jenkins en infra-as-code

Support de démonstration pour l'oral du Bloc 5 (RNCP Expert en architecture des Systèmes d'Information), lié au dossier Bloc 3 (Annexe G).

## Structure

| Dossier | Rôle |
|---|---|
| `infra/cluster/` | Pool(s) de nœuds Kapsule. `ha_enabled=true` ajoute 2 pools multi-zone (`fr-par-1`, `fr-par-3`) en plus du pool existant (`fr-par-2`) |
| `infra/state-backend/` | Bucket S3 + clé IAM pour le state distant du module `demo/` |
| `infra/jenkins/` | Cluster Kapsule (référencé) + Jenkins (Helm/JCasC/Job DSL) + passerelle WireGuard |
| `infra/monitoring/` | kube-prometheus-stack (Prometheus/Alertmanager/Grafana) |
| `target-infra/vms/outillage/` | VM `outillage` (tunnel WireGuard, bootstrap manuel) |
| `target-infra/vms/demo/` | VM(s) `demo` (créées par Jenkins, state séparé) |
| `deploy/Jenkinsfile.provision` | Pipeline `provision-demo-vm` (Terraform, menus réactifs ROLE/TARGET) |
| `deploy/Jenkinsfile.monitoring` | Pipeline `deploy-monitoring` (lint + tests + déploiement d'une stack Prometheus sur demo-0) |
| `deploy/monitoring-stack/` | Stack Prometheus/Alertmanager/node-exporter/pve-exporter/blackbox-exporter déployée sur `demo-0` |
| `deploy/Jenkinsfile.app` | Pipeline `deploy-app` (détecte les VM app en direct, menu de choix en cours de run) |
| `deploy/app/` | `docker-compose.yml` + `index.html` de l'appli de démo |
| `external-monitoring/uptime-kuma/` | Surveillance externe, volontairement hors Terraform (voir plus bas) |
| `wireguard/` | Clés WireGuard (gitignorées) |

`infra/state-backend/`, `infra/jenkins/` et `infra/monitoring/` ont chacun leur propre state Terraform, volontairement séparés : `state-backend/` ne dépend de rien et ne doit jamais être affecté par un test de reconstruction de Jenkins.

`provision-demo-vm` s'utilise via trois paramètres : `ROLE` (`monitoring` ou `app`), `TARGET` (`1` à `4`, ignoré si `ROLE=monitoring` qui cible toujours `demo-0`), et `REPLACE` qui détruit et recrée la VM ciblée au lieu de simplement s'assurer qu'elle existe.

`deploy-app` détecte en direct les VM app disponibles (ping sur `192.168.1.6`-`.9`) et propose un choix uniquement parmi celles qui répondent, en cours d'exécution du pipeline.

## Prérequis

Projet Scaleway, cluster Kapsule, VPS OVH + Proxmox + pfSense créés manuellement (hors Terraform).

Pour chaque module (`infra/cluster/`, `infra/state-backend/`, `infra/jenkins/`, `infra/monitoring/`, `target-infra/vms/outillage/`) :

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
  - **pfSense lui-même** (port WAN 51821, WireGuard natif pfSense, interface `VPN_COLLAB`) : poste de Maxime (`10.10.20.2`, permanent, accès "collaborateur").
- Chaque tunnel arrive sur un hôte différent, donc Proxmox a besoin d'une route statique par tunnel pour renvoyer ses réponses : `10.10.10.0/24 via 192.168.1.2` (outillage) et `10.10.20.0/24 via 192.168.1.1` (pfSense), ajoutées dans `/etc/network/interfaces` (`post-up ip route add ...` sur `vmbr1`).
- pfSense a l'option **"Bypass firewall rules for traffic on the same interface"** activée (System > Advanced > Firewall & NAT), nécessaire pour que le trafic TCP relayé par `outillage` (entrée et sortie sur la même interface LAN de pfSense) ne soit pas bloqué par le suivi d'état.
- VM(s) démo en IP statique à partir de `192.168.1.5` : `demo-0` (`.5`) porte le monitoring, `demo-1`+ (`.6`, `.7`, ...) portent l'appli de démo.

## Matrice de flux

| Source | Destination | Port/Proto | Objet | État |
|---|---|---|---|---|
| Internet | pfSense WAN `51.161.144.5` | UDP/51820 | Entrée WireGuard `outillage`, forwardé vers `192.168.1.2` | Existant |
| Internet | pfSense WAN `51.161.144.5` | UDP/51821 | Entrée WireGuard `VPN_COLLAB`, terminée sur pfSense | Existant |
| Internet | Proxmox `139.99.130.72` | TCP/8006 | API/WebUI Proxmox | Bloqué (pare-feu Proxmox) |
| gateway pod (`10.10.10.2`) | LAN `192.168.1.0/24` | tout | Tunnel permanent, relais socat (Proxmox, node_exporter) | Existant |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-0` (`192.168.1.5`) | TCP/22 | SSH, déploiement de la stack monitoring (`deploy-monitoring`) | Existant |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-1..4` (`192.168.1.6-9`) | TCP/22 | SSH, install Traefik+site (`deploy-app`) | Existant |
| Poste Maxime (`10.10.20.2`, VPN collaborateur) | LAN `192.168.1.0/24` | tout | Accès humain : Proxmox, démo, dépannage | Existant |
| Pod `provision-demo-vm` (Terraform, cluster) | Service `gateway.ci-cd.svc.cluster.local` | TCP/8006 | API Proxmox via relais socat, sans tunnel dédié | Existant |
| `infra/monitoring` (Prometheus) | Service `gateway.ci-cd.svc.cluster.local` | TCP/9100 | Scrape node_exporter de `demo-0` via relais socat | Existant |
| Jenkins (tous pipelines) | `github.com` | TCP/443 | Checkout du repo (Jenkinsfile, seed job) | Existant |
| Pod `provision-demo-vm` | Bucket `jenkins-poc-tfstate` (Scaleway S3) | TCP/443 | State Terraform distant | Existant |
| Poste Maxime | Jenkins (`ci-cd/svc/jenkins`) | TCP/8080 | UI Jenkins, port-forward ou LoadBalancer ponctuel | Existant |
| Poste Maxime | API Kubernetes Scaleway | TCP/443 | `kubectl`/Terraform sur `infra/jenkins`, `infra/monitoring` | Existant |
| OVH (hors bande) | Console KVM du serveur | - | Accès de secours à l'hôte Proxmox, indépendant du réseau/pare-feu | Existant (filet de sécurité) |
| Poste Maxime (Uptime Kuma) | API Kubernetes Scaleway + Jenkins (LoadBalancer) | TCP/443, TCP/8080 | Surveillance externe, indépendante du cluster surveillé | Existant |

## Test de reconstruction

```bash
cd infra/jenkins
terraform destroy -var="jenkins_service_type=LoadBalancer"
terraform apply -var="jenkins_service_type=LoadBalancer"
```

Jenkins revient dans le même état (plugins, JCasC, jobs, mot de passe admin fixé via `jenkins_admin_password`) sans action manuelle. La PVC (historique des builds, home Jenkins) survit elle aussi : elle porte l'annotation `helm.sh/resource-policy: keep` (valeur `persistence.annotations` du chart), qui empêche Helm de la supprimer au `destroy` et la fait ré-adopter au prochain `apply`. `infra/state-backend/` étant un module séparé, ce destroy/apply ne touche jamais au state du module `demo/`.

Vérifié en conditions réelles à deux reprises : la première fois sans l'annotation (PVC recréée, historique perdu), la seconde avec (PVC identique avant/après, même UID).

## Points ouverts

- LoadBalancer Jenkins/Grafana : `-var="jenkins_service_type=LoadBalancer"` / `-var="grafana_service_type=LoadBalancer"`, à repasser en `ClusterIP` après usage

## Redondance du cluster

Le control plane Kapsule est entièrement géré par Scaleway (offre standard, mutualisée) : sa disponibilité ne dépend pas de ce projet, et une offre à control plane dédié impliquerait de recréer le cluster, hors scope pour un PoC. En cas de panne du control plane, les workloads déjà déployés continuent de tourner (propriété de Kubernetes : kubelet ne dépend pas du control plane pour maintenir les conteneurs déjà programmés), mais plus aucune action (déploiement, replanification d'un pod qui crashe) n'est possible tant qu'il n'est pas revenu.

Le vrai levier actionnable est le pool de nœuds (`infra/cluster/`) : par défaut un seul nœud (`fr-par-2`, état d'origine du cluster, importé sans modification). `terraform apply -var="ha_enabled=true"` ajoute deux pools supplémentaires dans deux autres zones (`fr-par-1`, `fr-par-3`), configurés à l'identique du pool existant — redondance multi-zone plutôt que multi-nœuds dans la même zone, un pool Scaleway étant rattaché à une seule zone.

## Surveillance externe

Ni Prometheus ni Alertmanager ne peuvent alerter sur leur propre panne : ils vivent dans le cluster qu'ils surveillent. `external-monitoring/uptime-kuma/` ajoute un point de contrôle volontairement en dehors de Terraform et de Scaleway (sur le poste de Maxime), qui détecte une panne du cluster ou une panne générale Scaleway indépendamment de l'état du reste de la stack — y compris une panne du control plane que la redondance des pools ne couvre pas. Détails et cibles dans son propre README.

## Lien avec le dossier réel (Bloc 1-3)

`deploy/monitoring-stack/` et `deploy/Jenkinsfile.monitoring` reproduisent la structure et le pipeline du dépôt réel `monitoring_blagnac` (supervision du datacenter de Blagnac, documenté dans le Bloc 3) : mêmes étapes (lint des règles via `promtool check rules`, tests unitaires via `promtool test rules`, déploiement conditionnel par SSH via rebond réseau), même choix d'outils (Prometheus, Alertmanager, node-exporter, pve-exporter, blackbox-exporter), même schéma réseau (passerelle avec relais socat + rebond SSH via tunnel).

Sont volontairement omis : le scanner CVE (outil interne complexe, hors scope PoC), le snmp-exporter (pas de cible SNMP dans ce PoC), les webhooks Teams réels et les adresses IP de Peopulse — remplacés par des cibles génériques propres au PoC.

Cette proximité de structure permet une vraie comparaison de performance de pipeline (mêmes étapes, deux infrastructures Jenkins différentes) plutôt qu'un exemple de déploiement générique sans rapport avec le travail réel.

## Incident : verrouillage du pare-feu Proxmox

En activant le pare-feu Proxmox, les règles d'autorisation ajoutées juste avant sont restées décochées (case "On", désactivée par défaut à la création) : le pare-feu s'est activé avec une politique par défaut DROP et aucune règle active, coupant l'accès à l'interface web et au SSH de l'hôte, y compris pour l'administrateur. Restauré via la console KVM du serveur (accès hors bande fourni par OVH, indépendant du réseau du serveur) : `pve-firewall stop` en urgence, puis correction des règles et `pve-firewall start`. Aucune VM ni aucune donnée affectée, seul l'accès à l'hôte Proxmox lui-même a été interrompu.
