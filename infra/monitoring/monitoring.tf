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
        config = {
          global = {
            smtp_smarthost   = "${scaleway_tem_domain.alerts.smtp_host}:${scaleway_tem_domain.alerts.smtp_port}"
            smtp_from        = "alerting@${scaleway_tem_domain.alerts.name}"
            smtp_auth_username = scaleway_tem_domain.alerts.smtps_auth_user
            smtp_auth_password = scaleway_iam_api_key.alerting_smtp.secret_key
            smtp_require_tls   = true
          }
          route = {
            receiver = "email-alert"
            group_by = ["alertname"]
            routes = [
              {
                receiver = "email-alert"
                matchers = ["severity=~\"critical|warning\""]
              }
            ]
          }
          receivers = [
            {
              name = "email-alert"
              email_configs = [
                {
                  to          = var.alert_email
                  send_resolved = true
                }
              ]
            }
          ]
        }
      }
      grafana = {
        image = {
          tag = "13.0.9"
        }
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
            uid    = "demo0-prometheus"
            type   = "prometheus"
            url    = "http://gateway.ci-cd.svc.cluster.local:9090"
            access = "proxy"
          }
        ]
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
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

resource "kubernetes_ingress_v1" "grafana" {
  count = var.grafana_hostname != "" ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = "monitoring"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.grafana_hostname]
      secret_name = "grafana-tls"
    }

    rule {
      host = var.grafana_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "monitoring-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.monitoring]
}
