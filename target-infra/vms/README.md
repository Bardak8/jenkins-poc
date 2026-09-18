# VMs — outillage (bootstrap) et démo (pipeline Jenkins)

Deux ressources dans ce module, appliquées à des moments et par des acteurs différents :

| Ressource | Qui l'applique | Quand |
|---|---|---|
| `proxmox_virtual_environment_vm.outillage` | Maxime, manuellement | Après `target-infra/pfsense/`, avant tout pipeline Jenkins — porte le tunnel WireGuard |
| `proxmox_virtual_environment_vm.demo` | Jenkins, depuis le pipeline `deploy-monitoring-vm` | Une fois le tunnel établi, sur déclenchement du job |

## Prérequis

1. Un template Proxmox Debian avec cloud-init, préparé une fois (voir `../pfsense/README.md` pour la méthode équivalente côté pfSense — ici plus simple, un template Debian cloud générique convient).
2. `target-infra/pfsense/` déjà appliqué (le `lan_bridge` doit exister).

## Bootstrap de la VM outillage

```bash
terraform init
terraform plan   # ne doit montrer QUE outillage, pas demo (demo_vm_count reste géré par Jenkins ensuite)
terraform apply
```

Une fois la VM up, installer et configurer WireGuard dessus (client du tunnel site-à-site vers Jenkins/Scaleway) — voir `../../wireguard/`.

## Utilisation par Jenkins

Le pipeline exécute ce même module avec les credentials du token Proxmox stockés en Secret Kubernetes (jamais en clair), en pointant `proxmox_endpoint` sur l'IP privée (via le tunnel), pas l'IP publique. Il ne doit gérer que la ressource `demo` — au premier apply de la VM outillage par Maxime, l'état Terraform local reste sur son poste ; Jenkins tourne sur un state séparé qui ne connaît que `demo`, pour ne jamais risquer de recréer/détruire la VM outillage depuis le pipeline.

**Point d'attention non résolu à ce stade** : ce README suppose deux states Terraform distincts sur un même dossier de code (un pour `outillage`, un pour `demo`), ce qui demande soit un découpage plus fin (comme `infra/jenkins/` et `infra/monitoring/`), soit l'usage de `-target` (déconseillé en usage courant). À trancher avant la mise en place du pipeline (lot 5).
