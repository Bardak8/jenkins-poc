# Stockage répliqué pour Jenkins : contrairement à sbs-default (verrouillé
# à sa zone de création), Longhorn réplique le volume sur plusieurs nœuds.
# Si le nœud qui porte Jenkins meurt, une réplique saine ailleurs permet
# au pod de redémarrer sans attendre le retour du nœud d'origine.
#
# Premier essai (retiré depuis, cf. README) : sur un cluster à un seul
# nœud, les répliques n'avaient nulle part où aller et finissaient sur le
# même disque local, avec un incident de perte de données à la clé.
# Corrigé ici par deux garde-fous, tous deux nécessaires :
# - le pool passe à 3 nœuds répartis sur 3 zones (infra/cluster, ha_enabled)
# - l'anti-affinité est forcée en strict (false), pas laissée à sa valeur
#   par défaut permissive, pour que Longhorn refuse de recréer la même
#   situation même si un nœud venait à manquer temporairement
resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.longhorn_chart_version
  namespace        = "longhorn-system"
  create_namespace = true

  values = [
    yamlencode({
      persistence = {
        defaultClass             = false
        defaultClassReplicaCount = var.replica_count
      }
      defaultSettings = {
        defaultReplicaCount          = var.replica_count
        replicaSoftAntiAffinity      = false
        replicaZoneSoftAntiAffinity  = false
      }
      longhornManager = {
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
      longhornDriver = {
        resources = {
          requests = { cpu = "20m", memory = "64Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc]
}
