resource "kubernetes_secret" "isaac_db_credentials" {
  metadata {
    name      = "isaac-db-credentials"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    username = "isaac"
    password = base64decode(data.scaleway_secret_version.isaac_db_password.data)
  }
}
