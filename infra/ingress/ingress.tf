# IP réservée séparément du cycle de vie du Load Balancer lui-même : si
# le Service/Helm release ingress-nginx est un jour détruit et recréé
# (test de reconstruction, mise à jour majeure...), l'IP publique reste
# identique et le DNS n'a jamais besoin d'être retouché.
#
# Zone forcée à fr-par-1 : le cloud-controller-manager de Kapsule crée
# toujours ses Load Balancers dans cette zone, quelle que soit la zone
# du cluster (ici fr-par-2). Une IP réservée dans une autre zone donne
# une erreur "ip not Found" au moment du rattachement.
resource "scaleway_lb_ip" "ingress" {
  zone = "fr-par-1"
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/scw-loadbalancer-ip-ids" = element(split("/", scaleway_lb_ip.ingress.id), 1)
          }
        }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "300m", memory = "256Mi" }
        }
      }
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc, scaleway_lb_ip.ingress]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "150m", memory = "128Mi" }
      }
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc]
}

# Le ClusterIssuer dépend des CRD installées par cert-manager ci-dessus.
# Laisser enable_cluster_issuer=false au premier apply, puis repasser à
# true et ré-appliquer une fois cert-manager confirmé opérationnel
# (kubectl get pods -n cert-manager).
resource "kubernetes_manifest" "letsencrypt_prod" {
  count = var.enable_cluster_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}
