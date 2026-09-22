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

resource "kubernetes_config_map" "dashboard_proxmox" {
  metadata {
    name      = "dashboard-proxmox-via-prometheus"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "proxmox-via-prometheus.json" = file("${path.module}/dashboards/proxmox-via-prometheus.json")
  }

  depends_on = [helm_release.monitoring]
}

resource "kubernetes_config_map" "dashboard_watchdog" {
  metadata {
    name      = "dashboard-watchdog"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "watchdog.json" = file("${path.module}/dashboards/watchdog.json")
  }

  depends_on = [helm_release.monitoring]
}
