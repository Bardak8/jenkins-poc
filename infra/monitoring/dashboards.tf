resource "kubernetes_config_map" "dashboard_demo_poc" {
  metadata {
    name      = "dashboard-demo-poc"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "demo-poc.json" = file("${path.module}/dashboards/demo-poc.json")
  }

  depends_on = [helm_release.monitoring]
}

resource "kubernetes_config_map" "dashboard_demo_stack" {
  metadata {
    name      = "dashboard-demo-stack"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "demo-0-stack.json" = file("${path.module}/dashboards/demo-0-stack.json")
  }

  depends_on = [helm_release.monitoring]
}
