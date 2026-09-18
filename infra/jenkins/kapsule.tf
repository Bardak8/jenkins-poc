# Cluster Kapsule créé et géré manuellement par Maxime (console Scaleway,
# compte isolé dédié), jamais par Terraform. Ce module se contente de le
# référencer en lecture pour y déployer Jenkins (jenkins.tf).
#
# Le module monitoring/ référence le même cluster indépendamment, avec
# son propre state — aucune dépendance croisée entre les deux modules.

data "scaleway_k8s_cluster" "poc" {
  cluster_id = var.cluster_id
}
