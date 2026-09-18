# Stack de monitoring du PoC lui-même (observabilité du cluster Jenkins),
# dans un namespace séparé de Jenkins ET dans un state Terraform séparé
# du module jenkins/ — un destroy/apply sur l'un n'affecte jamais l'autre.
# Déployée une fois, pas destinée à être détruite/recréée comme test de
# reconstruction (contrairement à Jenkins).
#
# Reprend les mêmes outils que le projet réel (Prometheus, Alertmanager,
# Grafana), dimensionnés pour un nœud unique partagé avec Jenkins.

locals {
  # Règles d'alerte reprises et adaptées du dépôt Monitoring-Blagnac réel
  # (voir rules/*.yml pour le détail des adaptations).
  additional_rules = {
    nodes    = yamldecode(file("${path.module}/rules/nodes.yml"))
    watchdog = yamldecode(file("${path.module}/rules/watchdog.yml"))
  }
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.monitoring_chart_version
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      # Pas de stockage persistant pour ce PoC : rétention courte,
      # en mémoire du pod, pas de Block Storage supplémentaire à payer.
      prometheus = {
        prometheusSpec = {
          retention = "6h"
          resources = {
            requests = { cpu = "100m", memory = "512Mi" }
            limits   = { cpu = "500m", memory = "1Gi" }
          }
          storageSpec = {}
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = { cpu = "20m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
      }
      grafana = {
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
        # Mot de passe admin auto-généré par le chart dans un Secret
        # Kubernetes — jamais en clair ici. Récupération : voir output
        # grafana_admin_password_command.
        persistence = { enabled = false }
      }
      kubeStateMetrics = {
        resources = {
          requests = { cpu = "20m", memory = "64Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
      nodeExporter = {
        resources = {
          requests = { cpu = "20m", memory = "32Mi" }
          limits   = { cpu = "50m", memory = "64Mi" }
        }
      }
      additionalPrometheusRulesMap = local.additional_rules
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc]
}
