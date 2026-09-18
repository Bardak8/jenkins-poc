# VMs Proxmox

Deux modules Terraform indépendants, chacun avec son propre state.

| Module | Ressource | Qui l'applique | Quand |
|---|---|---|---|
| `outillage/` | VM `outillage` (vm_id 200) | Maxime, manuellement | Une fois, avant tout pipeline Jenkins — porte le tunnel WireGuard persistant |
| `demo/` | VM(s) `demo-*` (vm_id 300+) | Jenkins, pipeline `provision-demo-vm` | À chaque exécution du pipeline |

`demo-0` porte le monitoring (`deploy-monitoring`), `demo-1` et suivantes portent l'appli de démo (`deploy-app`).

State séparé volontairement : le pipeline `provision-demo-vm` tourne dans un pod Jenkins éphémère, sans state local. S'il partageait un module avec `outillage`, il tenterait de recréer une VM déjà existante à chaque run.

`demo/` utilise un backend distant (S3 sur Scaleway Object Storage, credentials injectées via secret Kubernetes `tfstate-credentials`) pour la même raison : sans ça, le state créé dans un run serait perdu à la fin du pod, et le run suivant tenterait de recréer une VM déjà existante. `outillage/` reste en state local puisqu'il est appliqué depuis la machine de Maxime, jamais depuis un pod éphémère.
