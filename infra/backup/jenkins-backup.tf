locals {
  s3_endpoint = "https://s3.${var.region}.scw.cloud"

  jenkins_tar_script = <<-EOT
    set -e
    DATE=$(date +%F)
    tar czf /shared/jenkins-home-$DATE.tar.gz -C /jenkins-home .
  EOT

  jenkins_upload_script = <<-EOT
    set -e
    aws --endpoint-url=${local.s3_endpoint} s3 cp /shared/ s3://${scaleway_object_bucket.backups.name}/jenkins-home/ --recursive --exclude "*" --include "jenkins-home-*.tar.gz"
    echo BACKUP_DONE
  EOT
}

resource "kubernetes_cron_job_v1" "jenkins_home_backup" {
  metadata {
    name      = "jenkins-home-backup-to-s3"
    namespace = "ci-cd"
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

            # jenkins-sbs est un volume Longhorn ReadWriteOnce, attaché
            # au nœud où tourne jenkins-0 : sans cette affinité, le job
            # atterrit parfois sur un autre nœud et reste bloqué
            # indéfiniment sur "Waiting for detach... Volume is already
            # used by pod(s) jenkins-0" (constaté en vrai). Colocalisé
            # dynamiquement avec jenkins-0, où qu'il soit (survit à un
            # failover), plutôt qu'un nœud codé en dur.
            affinity {
              pod_affinity {
                required_during_scheduling_ignored_during_execution {
                  label_selector {
                    match_labels = {
                      "app.kubernetes.io/component" = "jenkins-controller"
                    }
                  }
                  topology_key = "kubernetes.io/hostname"
                }
              }
            }

            init_container {
              name    = "tar"
              image   = "alpine:3.20"
              command = ["/bin/sh", "-c", local.jenkins_tar_script]

              volume_mount {
                name       = "jenkins-home"
                mount_path = "/jenkins-home"
                read_only  = true
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
              args    = [local.jenkins_upload_script]

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
              name = "jenkins-home"
              persistent_volume_claim {
                claim_name = "jenkins-sbs"
                read_only  = true
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
}
