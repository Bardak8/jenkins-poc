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
