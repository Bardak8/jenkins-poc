# Bucket complètement indépendant du cluster Kapsule : il survit à un
# destroy total du cluster, contrairement aux volumes CSI (SBS) qui
# restent, eux, liés au cycle de vie du cluster.
resource "scaleway_object_bucket" "backups" {
  name   = "jenkins-poc-backups"
  region = var.region

  lifecycle_rule {
    id      = "expire-old-backups"
    enabled = true

    expiration {
      days = var.retention_days
    }
  }
}

resource "scaleway_iam_application" "backups" {
  name = "jenkins-poc-backups"
}

resource "scaleway_iam_policy" "backups" {
  name           = "jenkins-poc-backups"
  application_id = scaleway_iam_application.backups.id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = ["ObjectStorageFullAccess"]
  }
}

resource "scaleway_iam_api_key" "backups" {
  application_id = scaleway_iam_application.backups.id
  expires_at     = "2027-06-30T00:00:00Z"
}

resource "kubernetes_secret" "backup_credentials_ci_cd" {
  metadata {
    name      = "backup-credentials"
    namespace = "ci-cd"
  }

  data = {
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.backups.access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.backups.secret_key
  }
}

resource "kubernetes_secret" "backup_credentials_apps" {
  metadata {
    name      = "backup-credentials"
    namespace = "apps"
  }

  data = {
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.backups.access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.backups.secret_key
  }
}

