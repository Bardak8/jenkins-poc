# PoC — Migration Jenkins en infra-as-code

Support de démonstration pour l'oral du Bloc 5 (RNCP Expert en architecture des Systèmes d'Information), lié au dossier Bloc 3 (Annexe G).

## Structure

| Dossier | Rôle |
|---|---|
| `infra/jenkins/` | Cluster Kapsule (référencé) + Jenkins (Helm/JCasC/Job DSL) + passerelle WireGuard |
| `infra/monitoring/` | kube-prometheus-stack (Prometheus/Alertmanager/Grafana) |
| `target-infra/vms/outillage/` | VM `outillage` (tunnel WireGuard, bootstrap manuel) |
| `target-infra/vms/demo/` | VM(s) `demo` (créées par Jenkins, state séparé) |
| `deploy/Jenkinsfile.provision` | Pipeline `provision-demo-vm` (Terraform, menus réactifs ROLE/TARGET) |
| `deploy/Jenkinsfile.monitoring` | Pipeline `deploy-monitoring` (node_exporter sur demo-0, fixe) |
| `deploy/Jenkinsfile.app` | Pipeline `deploy-app` (détecte les VM app en direct, menu de choix en cours de run) |
| `deploy/app/` | `docker-compose.yml` + `index.html` de l'appli de démo |
| `wireguard/` | Clés WireGuard (gitignorées) |

`infra/jenkins/` et `infra/monitoring/` ont chacun leur propre state Terraform.

`provision-demo-vm` s'utilise via trois paramètres : `ROLE` (`monitoring` ou `app`), `TARGET` (`1` à `4`, ignoré si `ROLE=monitoring` qui cible toujours `demo-0`), et `REPLACE` qui détruit et recrée la VM ciblée au lieu de simplement s'assurer qu'elle existe.

`deploy-app` détecte en direct les VM app disponibles (ping sur `192.168.1.6`-`.9`) et propose un choix uniquement parmi celles qui répondent, en cours d'exécution du pipeline.

## Prérequis

Projet Scaleway, cluster Kapsule, VPS OVH + Proxmox + pfSense créés manuellement (hors Terraform).

Pour chaque module (`infra/jenkins/`, `infra/monitoring/`, `target-infra/vms/outillage/`) :

```bash
terraform init
terraform plan
SCW_PROFILE=newprofile terraform apply
```

## Réseau

- pfSense : WAN `51.161.144.5/32` (MAC virtuelle OVH), gateway `139.99.130.72`. LAN `192.168.1.1/24`, DHCP `.100`-`.199`.
- Port forward WAN UDP 51820 → VM outillage.
- Trois peers WireGuard vers `outillage`, chacun avec sa propre clé et son IP sur `10.10.10.0/24` : passerelle (`10.10.10.2`, permanent, cluster Scaleway), pipeline de déploiement (`10.10.10.3`, éphémère), poste de Maxime (`10.10.10.4`, permanent, accès VPN collaborateur).
- VM(s) démo en IP statique à partir de `192.168.1.5` : `demo-0` (`.5`) porte le monitoring, `demo-1`+ (`.6`, `.7`, ...) portent l'appli de démo.

## Matrice de flux

| Source | Destination | Port/Proto | Objet | État |
|---|---|---|---|---|
| Internet | pfSense WAN `51.161.144.5` | UDP/51820 | Entrée WireGuard, forwardé vers `outillage` | Existant |
| Internet | Proxmox `139.99.130.72` | TCP/8006 | API/WebUI Proxmox, exposée publiquement | À fermer |
| gateway pod (`10.10.10.2`) | LAN `192.168.1.0/24` | tout | Tunnel permanent, relais socat (Proxmox, node_exporter) | Existant / à étendre |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-0` (`192.168.1.5`) | TCP/22 | SSH, install node_exporter (`deploy-monitoring`) | Existant |
| Pod pipeline déploiement (`10.10.10.3`, éphémère) | `demo-1..4` (`192.168.1.6-9`) | TCP/22 | SSH, install Traefik+site (`deploy-app`) | Existant |
| Poste Maxime (`10.10.10.4`, VPN collaborateur) | `demo-1..4` | TCP/80 | Navigation démo pendant l'oral | À faire |
| Poste Maxime (`10.10.10.4`) | Proxmox LAN (`192.168.1.3`, à définir) | TCP/8006 | Admin Proxmox via VPN uniquement | À faire |
| Pod `provision-demo-vm` (Terraform, cluster) | Service `gateway.ci-cd.svc.cluster.local` | TCP/8006 | API Proxmox via relais socat, sans tunnel dédié | À faire |
| `infra/monitoring` (Prometheus) | Service `gateway.ci-cd.svc.cluster.local` | TCP/9100 | Scrape node_exporter de `demo-0` via relais socat | À faire |
| Jenkins (tous pipelines) | `github.com` | TCP/443 | Checkout du repo (Jenkinsfile, seed job) | Existant |
| Pod `provision-demo-vm` | Bucket `jenkins-poc-tfstate` (Scaleway S3) | TCP/443 | State Terraform distant | Existant |
| Poste Maxime | Jenkins (`ci-cd/svc/jenkins`) | TCP/8080 | UI Jenkins, port-forward ou LoadBalancer ponctuel | Existant |
| Poste Maxime | API Kubernetes Scaleway | TCP/443 | `kubectl`/Terraform sur `infra/jenkins`, `infra/monitoring` | Existant |

## Test de reconstruction

```bash
cd infra/jenkins
terraform destroy
terraform apply
```

Jenkins doit revenir dans le même état (plugins, JCasC, jobs) sans action manuelle.

## Points ouverts

Voir les lignes "À faire" de la matrice de flux (fermeture de l'exposition publique de Proxmox, relais socat, accès VPN collaborateur).

- LoadBalancer Jenkins : `-var="jenkins_service_type=LoadBalancer"`, à repasser en `ClusterIP` après usage
