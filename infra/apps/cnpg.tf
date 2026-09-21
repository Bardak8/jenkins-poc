# CloudNativePG : opérateur Postgres pour Kubernetes. Remplace le
# Deployment Postgres "maison" par un vrai cluster avec réplication
# streaming et bascule automatique si le primaire tombe.
resource "helm_release" "cnpg_operator" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  namespace        = "cnpg-system"
  create_namespace = true

  depends_on = [data.scaleway_k8s_cluster.poc]
}

# Le secret doit être de type kubernetes.io/basic-auth pour que CNPG
# l'accepte comme credentials applicatifs au bootstrap.
resource "kubernetes_secret" "isaac_db_credentials_basic_auth" {
  metadata {
    name      = "isaac-db-credentials-basic-auth"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = "isaac"
    password = base64decode(data.scaleway_secret_version.isaac_db_password.data)
  }
}

resource "kubectl_manifest" "isaac_postgres_cluster" {
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "isaac-postgres"
      namespace = kubernetes_namespace.apps.metadata[0].name
    }
    spec = {
      instances = 2

      storage = {
        size         = "2Gi"
        storageClass = "sbs-default"
      }

      bootstrap = {
        initdb = {
          database = "isaac"
          owner    = "isaac"
          secret = {
            name = kubernetes_secret.isaac_db_credentials_basic_auth.metadata[0].name
          }
        }
      }
    }
  })

  depends_on = [helm_release.cnpg_operator]
}
