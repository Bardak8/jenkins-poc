# Segmentation du namespace ci-cd, construite à partir des flux réels
# vérifiés en direct (kubectl get svc/endpoints), pas de suppositions :
# - collab-gateway n'a aucun Service, son tunnel WireGuard sort en connexion
#   sortante vers le relais ; un refus d'ENTRÉE ne le concerne pas (le
#   retour de connexion est autorisé par le suivi de connexion).
# - jenkins reçoit sur 8080 seulement depuis collab-gateway (le socat qui
#   relaie l'accès humain).
# - gateway reçoit sur 8006 depuis jenkins (accès API Proxmox pour
#   target-infra/vms) et sur 9100/9090 depuis le namespace monitoring
#   (scraping Prometheus des métriques OVH/Proxmox de démo).
resource "kubernetes_network_policy_v1" "cicd_default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = "ci-cd"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_collab_gateway_to_jenkins" {
  metadata {
    name      = "allow-collab-gateway-to-jenkins"
    namespace = "ci-cd"
  }

  spec {
    pod_selector {
      match_labels = { "app.kubernetes.io/component" = "jenkins-controller" }
    }

    ingress {
      from {
        pod_selector {
          match_labels = { app = "collab-gateway" }
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

resource "kubernetes_network_policy_v1" "allow_jenkins_to_gateway_proxmox" {
  metadata {
    name      = "allow-jenkins-to-gateway-proxmox"
    namespace = "ci-cd"
  }

  spec {
    pod_selector {
      match_labels = { app = "gateway" }
    }

    ingress {
      from {
        pod_selector {
          match_labels = { "app.kubernetes.io/component" = "jenkins-controller" }
        }
      }

      ports {
        port     = "8006"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_monitoring_scrape_gateway" {
  metadata {
    name      = "allow-monitoring-scrape-gateway"
    namespace = "ci-cd"
  }

  spec {
    pod_selector {
      match_labels = { app = "gateway" }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "monitoring" }
        }
      }

      ports {
        port     = "9100"
        protocol = "TCP"
      }
      ports {
        port     = "9090"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
