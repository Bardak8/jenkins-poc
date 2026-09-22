# Volume répliqué (Longhorn, infra/jenkins/longhorn.tf) : contrairement à
# sbs-default, verrouillé à sa zone de création, ce volume a des répliques
# sur plusieurs nœuds/zones. Si le nœud qui porte Jenkins meurt, une
# réplique saine ailleurs permet au pod de redémarrer sans attendre le
# retour du nœud d'origine.
resource "kubernetes_persistent_volume_claim" "jenkins_sbs" {
  metadata {
    name      = "jenkins-sbs"
    namespace = "ci-cd"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "longhorn"

    resources {
      requests = {
        storage = "8Gi"
      }
    }
  }

  wait_until_bound = false

  depends_on = [helm_release.longhorn]
}
