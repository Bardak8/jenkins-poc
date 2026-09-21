locals {
  jenkins_backup_retention_count = 7
}

resource "kubernetes_service_account" "jenkins_backup" {
  metadata {
    name      = "jenkins-backup"
    namespace = "ci-cd"
  }
}

resource "kubernetes_role" "jenkins_backup" {
  metadata {
    name      = "jenkins-backup"
    namespace = "ci-cd"
  }

  rule {
    api_groups = ["snapshot.storage.k8s.io"]
    resources  = ["volumesnapshots"]
    verbs      = ["create", "get", "list", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding" "jenkins_backup" {
  metadata {
    name      = "jenkins-backup"
    namespace = "ci-cd"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_backup.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins_backup.metadata[0].name
    namespace = "ci-cd"
  }
}

resource "kubernetes_cron_job_v1" "jenkins_backup" {
  metadata {
    name      = "jenkins-home-backup"
    namespace = "ci-cd"
  }

  spec {
    schedule                      = "0 3 * * *"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account.jenkins_backup.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = "snapshot"
              image = "alpine/k8s:1.29.2"

              command = ["/bin/sh", "-c"]
              args = [
                <<-EOT
                set -eu
                NAME="jenkins-home-$(date -u +%Y%m%d%H%M%S)"
                kubectl -n ci-cd apply -f - <<EOF
                apiVersion: snapshot.storage.k8s.io/v1
                kind: VolumeSnapshot
                metadata:
                  name: $NAME
                  namespace: ci-cd
                  labels:
                    app: jenkins-backup
                spec:
                  volumeSnapshotClassName: scw-snapshot-retain
                  source:
                    persistentVolumeClaimName: jenkins-sbs
                EOF
                echo "Snapshot $NAME créé."

                kubectl -n ci-cd get volumesnapshot -l app=jenkins-backup \
                  --sort-by=.metadata.creationTimestamp -o name \
                  | head -n -${local.jenkins_backup_retention_count} \
                  | xargs -r kubectl -n ci-cd delete
                EOT
              ]
            }
          }
        }
      }
    }
  }
}
