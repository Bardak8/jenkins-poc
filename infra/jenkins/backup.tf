# Sauvegarde du volume Jenkins (build history, workspace), pour fermer
# le trou de RPO sur le scénario "perte totale du cluster" : sans ça,
# seule la configuration (JCasC, jobs) est reconstructible depuis le
# dépôt, l'historique de build serait perdu.
#
# Solution native, sans outil tiers : le cluster expose déjà les CRD
# VolumeSnapshot et une classe scw-snapshot-retain (politique Retain,
# le snapshot survit même si le PVC ou le pod source est supprimé —
# donc même si infra/jenkins/ est détruit pour le test de reconstruction
# du README, les snapshots pris avant restent disponibles).
# Un CronJob léger (kubectl + un peu de shell) déclenche un snapshot
# quotidien et purge les plus anciens au-delà de la rétention.

locals {
  jenkins_backup_retention_count = 7 # nombre de snapshots conservés (jours)
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
    schedule                      = "0 3 * * *" # tous les jours à 3h
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
              image = "bitnami/kubectl:1.31"

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
                    persistentVolumeClaimName: jenkins
                EOF
                echo "Snapshot $NAME créé."

                # Purge : ne garde que les N plus récents (par date de création).
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
