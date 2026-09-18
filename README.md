# PoC — Migration Jenkins en infra-as-code

Support de démonstration pour l'oral du Bloc 5 (RNCP Expert en architecture des Systèmes d'Information), lié au dossier Bloc 3 (Annexe G).

## Structure

| Dossier | Rôle |
|---|---|
| `infra/jenkins/` | Cluster Kapsule (référencé) + Jenkins (Helm/JCasC/Job DSL) + passerelle WireGuard |
| `infra/monitoring/` | kube-prometheus-stack (Prometheus/Alertmanager/Grafana) |
| `target-infra/vms/outillage/` | VM `outillage` (tunnel WireGuard, bootstrap manuel) |
| `target-infra/vms/demo/` | VM(s) `demo` (créées par Jenkins, state séparé) |
| `deploy/Jenkinsfile.provision` | Pipeline `provision-demo-vm` |
| `deploy/Jenkinsfile.deploy` | Pipeline `deploy-node-exporter` |
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
- VM démo en IP statique `192.168.1.5`.

## Test de reconstruction

```bash
cd infra/jenkins
terraform destroy
terraform apply
```

Jenkins doit revenir dans le même état (plugins, JCasC, jobs) sans action manuelle.

## Points ouverts

- Relais socat passerelle → Grafana (métriques node_exporter de la VM démo)
- LoadBalancer Jenkins : `-var="jenkins_service_type=LoadBalancer"`, à repasser en `ClusterIP` après usage
