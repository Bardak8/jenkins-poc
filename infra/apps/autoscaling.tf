# Scalabilité applicative horizontale : si les pods isaac-fansite sont
# en surcharge CPU, le HPA en crée un autre plutôt que de laisser la
# charge saturer les pods existants, répartie ensuite par le Service
# Kubernetes existant (isaac-app.tf) sans configuration supplémentaire.
#
# Horizontale plutôt que verticale (VPA) : plus simple à démontrer en
# conditions réelles (kubectl get pods pendant une charge), et le VPA
# nécessite un contrôleur séparé à déployer en plus du cluster.
#
# La scalabilité des nœuds eux-mêmes (cluster autoscaler, si les DEUX
# clusters Kapsule sont en surcharge) reste volontairement non
# implémentée ici : voir la slide "Vers une architecture de production"
# du support de soutenance, ce n'est pas un axe d'amélioration optionnel
# mais un prérequis de mise en production non démontré pour limiter le
# coût du PoC.
resource "kubernetes_horizontal_pod_autoscaler_v2" "isaac_fansite" {
  metadata {
    name      = "isaac-fansite"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.isaac_fansite.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}
