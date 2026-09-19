resource "kubernetes_persistent_volume_claim" "jenkins_longhorn" {
  metadata {
    name      = "jenkins-longhorn"
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
}
