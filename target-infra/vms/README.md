# VMs Proxmox

Deux modules Terraform indépendants, chacun avec son propre state.

| Module | Ressource | Qui l'applique | Quand |
|---|---|---|---|
| `outillage/` | VM `outillage` (vm_id 200) | Maxime, manuellement | Une fois, avant tout pipeline Jenkins — porte le tunnel WireGuard persistant |
| `demo/` | VM(s) `demo-*` (vm_id 300+) | Jenkins, pipeline `provision-demo-vm` | À chaque exécution du pipeline |

State séparé volontairement : le pipeline `provision-demo-vm` tourne dans un pod Jenkins éphémère, sans state local. S'il partageait un module avec `outillage`, il tenterait de recréer une VM déjà existante à chaque run.
