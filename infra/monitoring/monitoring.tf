locals {
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
      prometheus = {
        prometheusSpec = {
          retention = "6h"
          resources = {
            requests = { cpu = "100m", memory = "512Mi" }
            limits   = { cpu = "500m", memory = "1Gi" }
          }
          storageSpec = {}
          additionalScrapeConfigs = [
            {
              job_name = "demo-node-exporter"
              static_configs = [
                { targets = ["gateway.ci-cd.svc.cluster.local:9100"] }
              ]
            }
          ]
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
        service = {
          type = var.grafana_service_type
        }
        sidecar = {
          dashboards = {
            folderAnnotation = "grafana_folder"
          }
        }
        additionalDataSources = [
          {
            name   = "Demo-0 Prometheus"
            type   = "prometheus"
            url    = "http://gateway.ci-cd.svc.cluster.local:9090"
            access = "proxy"
          }
        ]
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
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
