resource "kubernetes_config_map" "dashboard_demo_poc" {
  metadata {
    name      = "dashboard-demo-poc"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "demo-poc.json" = file("${path.module}/dashboards/demo-poc.json")
  }

  depends_on = [helm_release.monitoring]
}
