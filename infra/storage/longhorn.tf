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
        defaultReplicaCount = var.replica_count
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
