# PoC — Migration Jenkins en infra-as-code

Support de démonstration pour l'oral du Bloc 5 (RNCP Expert en architecture des Systèmes d'Information), lié au dossier Bloc 3 (Annexe G).

## Structure

| Dossier | Rôle |
|---|---|
| `infra/jenkins/` | Cluster Kapsule (référencé) + Jenkins (Helm/JCasC/Job DSL) + passerelle WireGuard |
| `infra/monitoring/` | kube-prometheus-stack (Prometheus/Alertmanager/Grafana) |
| `target-infra/vms/outillage/` | VM `outillage` (tunnel WireGuard, bootstrap manuel) |
| `target-infra/vms/demo/` | VM(s) `demo` (créées par Jenkins, state séparé) |
| `deploy/Jenkinsfile.provision` | Pipeline `provision-demo-vm` (Terraform : crée/remplace les VM demo) |
| `deploy/Jenkinsfile.monitoring` | Pipeline `deploy-monitoring` (node_exporter sur demo-0, fixe) |
| `deploy/Jenkinsfile.app` | Pipeline `deploy-app` (Traefik + site sur demo-1 et suivantes) |
| `deploy/app/` | `docker-compose.yml` + `index.html` de l'appli de démo |
| `wireguard/` | Clés WireGuard (gitignorées) |

`infra/jenkins/` et `infra/monitoring/` ont chacun leur propre state Terraform.

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
- Tunnel WireGuard permanent : passerelle (cluster Scaleway) ↔ VM outillage.
- Tunnel éphémère dédié au pipeline de déploiement (peer distinct).
- VM(s) démo en IP statique à partir de `192.168.1.5` : `demo-0` (`.5`) porte le monitoring, `demo-1`+ (`.6`, `.7`, ...) portent l'appli de démo.

## Test de reconstruction

```bash
cd infra/jenkins
terraform destroy
terraform apply
```

Jenkins doit revenir dans le même état (plugins, JCasC, jobs) sans action manuelle.

## Points ouverts

- Relais socat passerelle → Grafana (métriques node_exporter de `demo-0`)
- Accès navigateur au site de démo (`demo-1`+, port 80) : à faire via le tunnel WireGuard ou un accès réseau vers `192.168.1.0/24`
- LoadBalancer Jenkins : `-var="jenkins_service_type=LoadBalancer"`, à repasser en `ClusterIP` après usage
