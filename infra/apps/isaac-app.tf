# Le pipeline "deploy-isaac-app" pousse toujours un tag ":latest" en plus
# du tag numéroté/release (voir JenkinsFIle du repo Isaac-Api). Le
# Deployment pointe donc sur ce tag stable : il survit à un destroy/apply
# du cluster en repartant sur la dernière image qui a réellement tourné.
# Seule exception : le tout premier apply, avant qu'aucun build n'ait
# jamais été lancé (registre vide) — les pods restent en ImagePullBackOff
# jusqu'au premier passage du job Jenkins "deploy-isaac-app".
resource "kubernetes_deployment" "isaac_fansite" {
  wait_for_rollout = false

  metadata {
    name      = "isaac-fansite"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "isaac-fansite" }
    }

    template {
      metadata {
        labels = { app = "isaac-fansite" }
      }

      spec {
        container {
          name  = "isaac-fansite"
          image = "${scaleway_registry_namespace.apps.endpoint}/isaac-fansite:latest"

          port {
            container_port = 8080
          }

          env {
            name  = "DB_HOST"
            value = "isaac-postgres-rw"
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_NAME"
            value = "isaac"
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.isaac_db_credentials.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.isaac_db_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "200m", memory = "128Mi" }
          }
        }
      }
    }
  }

  # Le HorizontalPodAutoscaler (autoscaling.tf) pilote replicas en direct
  # une fois déployé : sans ce lifecycle, Terraform le ramènerait à 2 à
  # chaque apply et se battrait avec lui.
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service" "isaac_fansite" {
  metadata {
    name      = "isaac-fansite"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    selector = { app = "isaac-fansite" }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress_v1" "isaac_fansite" {
  count = var.isaac_hostname != "" ? 1 : 0

  metadata {
    name      = "isaac-fansite"
    namespace = kubernetes_namespace.apps.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.isaac_hostname]
      secret_name = "isaac-fansite-tls"
    }

    rule {
      host = var.isaac_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.isaac_fansite.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
