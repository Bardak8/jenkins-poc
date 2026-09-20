# Déploiement initial "coquille vide" : l'image ci-dessous n'existe pas
# encore au premier apply (les pods restent en ImagePullBackOff), c'est
# attendu. Lancer le job Jenkins "deploy-isaac-app" une première fois
# pour builder et pousser une image réelle (voir output "next_step").
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
          image = "${scaleway_registry_namespace.apps.endpoint}/isaac-fansite:bootstrap"

          port {
            container_port = 8080
          }

          env {
            name  = "DB_HOST"
            value = kubernetes_service.isaac_postgres.metadata[0].name
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
