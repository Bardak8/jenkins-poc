# Segmentation interne au cluster : le VPN et le pare-feu contrôlent déjà
# l'accès humain (voir module jenkins), mais rien ne segmentait le trafic
# entre pods à l'intérieur du namespace apps. Ces NetworkPolicy appliquent
# un refus par défaut, puis n'autorisent explicitement que les flux réels
# du namespace : ingress-nginx -> isaac-fansite -> isaac-postgres, plus la
# réplication interne CloudNativePG et le scraping Prometheus.
resource "kubernetes_network_policy_v1" "apps_default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_ingress_to_isaac_fansite" {
  metadata {
    name      = "allow-ingress-to-isaac-fansite"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "isaac-fansite" }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "ingress-nginx" }
        }
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_to_isaac_postgres" {
  metadata {
    name      = "allow-to-isaac-postgres"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { "cnpg.io/cluster" = "isaac-postgres" }
    }

    ingress {
      # Trafic applicatif depuis isaac-fansite
      from {
        pod_selector {
          match_labels = { app = "isaac-fansite" }
        }
      }

      # Réplication streaming entre le primaire et la réplique
      from {
        pod_selector {
          match_labels = { "cnpg.io/cluster" = "isaac-postgres" }
        }
      }

      # Pods de restauration/maintenance ponctuels (scripts/demo-restore-from-backup.sh),
      # label posé explicitement sur ces pods éphémères, jamais sur autre chose
      from {
        pod_selector {
          match_labels = { role = "db-admin-access" }
        }
      }

      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_cnpg_operator_status" {
  metadata {
    name      = "allow-cnpg-operator-status"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { "cnpg.io/cluster" = "isaac-postgres" }
    }

    ingress {
      # L'opérateur CNPG (namespace cnpg-system) interroge chaque instance
      # sur son port de statut (8000) pour connaître l'état du cluster
      # (primaire, réplication, santé). Flux manquant ici initialement :
      # découvert via `kubectl describe cluster` qui remontait "Instance
      # Status Extraction Error: HTTP communication issue" une fois le
      # refus par défaut en place.
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "cnpg-system" }
        }
      }

      ports {
        port     = "8000"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_monitoring_scrape_isaac_postgres" {
  metadata {
    name      = "allow-monitoring-scrape-isaac-postgres"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { "cnpg.io/cluster" = "isaac-postgres" }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "monitoring" }
        }
      }

      ports {
        port     = "9187"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
