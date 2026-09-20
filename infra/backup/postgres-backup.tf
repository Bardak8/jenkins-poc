locals {
  postgres_upload_script = <<-EOT
    set -e
    aws --endpoint-url=${local.s3_endpoint} s3 cp /shared/isaac-dump.sql.gz s3://${scaleway_object_bucket.backups.name}/isaac-postgres/isaac-$(date +%F).sql.gz
    echo BACKUP_DONE
  EOT
}

resource "kubernetes_cron_job_v1" "isaac_postgres_backup" {
  metadata {
    name      = "isaac-postgres-backup-to-s3"
    namespace = "apps"
  }

  spec {
    schedule                      = "0 3 * * *"
    concurrency_policy             = "Forbid"
    successful_jobs_history_limit  = 3
    failed_jobs_history_limit      = 3

    job_template {
      metadata {}
      spec {
        backoff_limit = 1

        template {
          metadata {}
          spec {
            restart_policy = "Never"

            init_container {
              name  = "pg-dump"
              image = "postgres:16-alpine"
              command = [
                "sh", "-c",
                "pg_dump -h isaac-postgres-rw -U \"$POSTGRES_USER\" -d isaac | gzip > /shared/isaac-dump.sql.gz"
              ]

              env {
                name = "POSTGRES_USER"
                value_from {
                  secret_key_ref {
                    name = "isaac-db-credentials"
                    key  = "username"
                  }
                }
              }
              env {
                name = "PGPASSWORD"
                value_from {
                  secret_key_ref {
                    name = "isaac-db-credentials"
                    key  = "password"
                  }
                }
              }

              volume_mount {
                name       = "shared"
                mount_path = "/shared"
              }
            }

            container {
              name    = "upload"
              image   = "amazon/aws-cli:2.17.62"
              command = ["/bin/sh", "-c"]
              args    = [local.postgres_upload_script]

              env {
                name  = "AWS_DEFAULT_REGION"
                value = var.region
              }
              env {
                name = "AWS_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = "backup-credentials"
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              }
              env {
                name = "AWS_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = "backup-credentials"
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              }

              volume_mount {
                name       = "shared"
                mount_path = "/shared"
              }
            }

            volume {
              name = "shared"
              empty_dir {}
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.backup_credentials_apps]
}
