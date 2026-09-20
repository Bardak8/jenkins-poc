# Volume réseau (CSI Scaleway natif) : détaché du nœud, contrairement à
# Longhorn. Si un nœud meurt, le volume se rattache automatiquement à un
# nœud sain (pas de perte de données, juste le temps que Kubernetes
# reprogramme le pod ailleurs).
resource "kubernetes_persistent_volume_claim" "jenkins_sbs" {
  metadata {
    name      = "jenkins-sbs"
    namespace = "ci-cd"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "sbs-default"

    resources {
      requests = {
        storage = "8Gi"
      }
    }
  }

  wait_until_bound = false
}
