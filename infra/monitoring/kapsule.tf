# Même cluster que le module jenkins/, référencé indépendamment (state
# Terraform séparé). Voir infra/jenkins/kapsule.tf pour le commentaire
# complet sur la gestion manuelle du cluster.

data "scaleway_k8s_cluster" "poc" {
  cluster_id = var.cluster_id
}
