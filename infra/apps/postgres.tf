resource "kubernetes_secret" "isaac_db_credentials" {
  metadata {
    name      = "isaac-db-credentials"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    username = "isaac"
    password = var.isaac_db_password
  }
}

resource "kubernetes_persistent_volume_claim" "isaac_postgres" {
  metadata {
    name      = "isaac-postgres-longhorn"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "longhorn"

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }

  wait_until_bound = false
}

resource "kubernetes_deployment" "isaac_postgres" {
  wait_for_rollout = false

  metadata {
    name      = "isaac-postgres"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "isaac-postgres" }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "isaac-postgres" }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_DB"
            value = "isaac"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.isaac_db_credentials.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.isaac_db_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "postgres"
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "300m", memory = "256Mi" }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.isaac_postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "isaac_postgres" {
  metadata {
    name      = "isaac-postgres"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    selector = { app = "isaac-postgres" }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}
