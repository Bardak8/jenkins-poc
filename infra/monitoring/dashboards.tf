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

resource "kubernetes_config_map" "dashboard_proxmox_vm_select" {
  metadata {
    name      = "dashboard-proxmox-vm-select"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "proxmox-vm-select.json" = file("${path.module}/dashboards/proxmox-vm-select.json")
  }

  depends_on = [helm_release.monitoring]
}

resource "kubernetes_config_map" "dashboard_cluster_k8s" {
  metadata {
    name      = "dashboard-cluster-k8s"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "PoC"
    }
  }

  data = {
    "cluster-k8s.json" = file("${path.module}/dashboards/cluster-k8s.json")
  }

  depends_on = [helm_release.monitoring]
}
