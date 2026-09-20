# Nécessite infra/ingress/ (ingress-nginx + cert-manager + ClusterIssuer)
# déjà appliqué. Ne crée rien tant que jenkins_hostname est vide.
resource "kubernetes_ingress_v1" "jenkins" {
  count = var.jenkins_hostname != "" ? 1 : 0

  metadata {
    name      = "jenkins"
    namespace = "ci-cd"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.jenkins_hostname]
      secret_name = "jenkins-tls"
    }

    rule {
      host = var.jenkins_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "jenkins"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.jenkins]
}
