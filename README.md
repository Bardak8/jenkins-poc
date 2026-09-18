# PoC — Migration Jenkins en infra-as-code

PoC personnel construit pour l'épreuve orale du Bloc 5 (titre RNCP Expert en
architecture des Systèmes d'Information), en support du dossier Bloc 3
(partie 5.1.2 et Annexe G) qui identifie la reconstruction de Jenkins en
infra-as-code comme axe d'amélioration prioritaire chez Peopulse.

**Isolation** : ce PoC vit intégralement dans un projet Scaleway dédié,
créé et géré manuellement (pas par Terraform), séparé de toute autre
infrastructure. Aucune ressource existante n'est référencée ou modifiée
par ce dépôt.

## Ce que le PoC démontre

1. **Jenkins reconstruit de zéro, sans action manuelle** : cluster Kubernetes
   (Kapsule) provisionné par Terraform, Jenkins déployé par Helm, entièrement
   configuré par Jenkins Configuration as Code (JCasC) et Job DSL — aucun clic
   dans l'interface pour obtenir un contrôleur fonctionnel avec son pipeline.
2. **Jenkins sert réellement à déployer quelque chose, ailleurs** : le pipeline
   `deploy-monitoring-vm` pilote un second Terraform (provider Proxmox) pour
   créer une VM/conteneur sur un Proxmox hébergé chez OVH, puis y déploie une
   application de démonstration. La cible est volontairement un hébergeur et
   un environnement différents de ceux qui portent Jenkins — cela rejoue le
   couple EKS ↔ datacenter de Blagnac décrit dans les dossiers Bloc 1 et 3,
   avec la problématique réseau que ça implique.

## Structure

| Dossier | Rôle | Statut |
|---|---|---|
| `infra/jenkins/` | Provider Scaleway : cluster Kapsule (référencé, créé à la main) + Jenkins (ns `ci-cd`, Helm/JCasC/Job DSL). State Terraform propre. | Lot 2-3 en cours |
| `infra/monitoring/` | Stack d'observabilité du PoC (ns `monitoring`, kube-prometheus-stack : Prometheus/Alertmanager/Grafana). Règles d'alerte (`rules/`) reprises et adaptées du dépôt Monitoring-Blagnac réel (nodes, watchdog). State Terraform propre, indépendant de `jenkins/`. | Lot 2-3 en cours |
| `target-infra/vms/` | Provider Proxmox : VM `outillage` (tunnel WireGuard, bootstrap manuel) + VM `demo` (créée par Jenkins). pfSense n'est plus géré par Terraform (configuré manuellement une fois, voir plus bas). | Lot 4, en cours |
| `wireguard/` | Tunnel entre le cluster Scaleway et la VM outillage OVH | Lot 4, à venir |
| `deploy/` | Déploiement de l'application de démonstration sur la VM cible | Lot 4-5, à venir |
| `Jenkinsfile` | Pipeline déclaratif du job de démonstration | Lot 5, à venir |

**Pourquoi deux modules Terraform séparés** : `jenkins/` et `monitoring/`
référencent le même cluster mais ont chacun leur propre state. Un
`terraform destroy` sur l'un ne touche jamais l'autre — utile pour tester la
reconstruction de Jenkins (voir plus bas) sans perdre l'observabilité du
PoC, et inversement.

## Prérequis avant le premier `terraform apply`

Le projet Scaleway isolé et le cluster Kapsule (pool `DEV1-L`, 1 nœud,
zone `fr-par-2`) sont créés **manuellement** via la console, sur un compte
Scaleway séparé de toute autre infra. Terraform ne fait que déployer dessus
(`kapsule.tf` de chaque module référence le cluster en data source, il ne le
crée ni ne le détruit jamais).

Pour chacun des deux modules (`infra/jenkins/` et `infra/monitoring/`) :

1. `terraform.tfvars` contient déjà `project_id` et `cluster_id` du cluster
   existant (fichier gitignoré, jamais poussé, identique dans les deux
   modules).
2. Configurer les credentials Scaleway du compte isolé en variables
   d'environnement (`SCW_ACCESS_KEY`/`SCW_SECRET_KEY`, ou `SCW_PROFILE` si
   vous utilisez un profil nommé) — jamais dans ce dépôt, et bien vérifier
   qu'elles pointent sur le bon compte (pas celui utilisé par ailleurs pour
   Bamboo/Platform).
3. `terraform init && terraform plan` dans le module concerné, pour
   vérifier avant tout `apply`.

## Procédure de reconstruction (test de PRA du PoC lui-même)

Comme pratiqué dans le dossier Bloc 1 pour la chaîne Thanos (bucket vidé puis
reconstruit par backfill), l'objectif est de prouver la reconstruction, pas
seulement de l'affirmer :

1. `terraform destroy` dans `infra/jenkins/` uniquement.
2. `terraform apply` à nouveau, sans aucune autre action.
3. Vérifier que Jenkins revient dans le même état (plugins, JCasC, job
   `deploy-monitoring-vm` présent) sans intervention manuelle, et que la
   stack de monitoring (`infra/monitoring/`, jamais touchée par ce cycle)
   a continué de tourner sans interruption.

## Réseau (pfSense, configuration manuelle)

pfSense est une pièce d'infrastructure statique sur ce PoC, configurée une
fois manuellement, pas gérée par Terraform (voir la discussion : le
bénéfice de la rendre clonable n'apportait rien aux compétences évaluées,
seule la reconstruction de Jenkins et la création de la VM de démo
comptent réellement).

- **WAN** (1ère carte, `vmbr0`) : `51.161.144.5/32` (IP additionnelle OVH,
  avec MAC virtuelle assignée à `net0` de la VM pfSense — l'IP principale
  du serveur, `139.99.130.72`, reste sur Proxmox/l'hôte, pas sur la VM).
  Gateway : `139.99.130.72` (convention OVH pour les IP additionnelles).
- **LAN** (2e carte, `vmbr1`, bridge Proxmox purement virtuel, sans port
  physique) : `192.168.1.1/24`, DHCP sur `192.168.1.100`-`192.168.1.199`
  pour les VM internes (valeurs par défaut de l'installeur pfSense,
  conservées telles quelles).
- **NAT sortant** : automatique (mode par défaut de pfSense), les VM du
  LAN sortent vers Internet sans configuration supplémentaire.
- **NAT entrant (port forward)** : WAN UDP 51820 → IP LAN de la VM
  outillage (réservation DHCP statique conseillée), c'est le seul port
  ouvert depuis l'extérieur — exactement le rôle que joue pfSense côté
  Blagnac dans le projet réel, le tunnel WireGuard entrant chez lui mais
  porté par la VM outillage, pas par pfSense lui-même.
- Config exportée (`Diagnostics > Backup & Restore`) et versionnée dans ce
  dépôt une fois stabilisée, pour la traçabilité.

## Points ouverts

- Nested virtualization sur le VPS OVH à vérifier avant commande (KVM vs LXC
  dans Proxmox — voir le plan de travail).
- Application de démonstration déployée sur la cible Proxmox : pas encore
  arrêtée (piste actuelle : stack de monitoring légère).
- Gestion des secrets (token Git, accès Proxmox, clés WireGuard) : à définir
  au lot 4, sur le même principe que le projet réel (jamais en clair,
  déchiffrés au déploiement).
