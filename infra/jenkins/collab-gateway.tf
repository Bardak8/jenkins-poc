# Deuxième passerelle WireGuard, dédiée à l'accès collaborateur (humain)
# vers Jenkins et Grafana, distincte de la passerelle "outillage"
# (gateway.tf) qui reste réservée à l'automatisation. Compose vers le
# relais Scaleway (infra/relay/), jamais exposée publiquement : ni
# Jenkins ni Grafana ne sont joignables hors connexion au VPN du relais
# (grafana_hostname reste vide dans infra/monitoring, donc pas d'Ingress
# public pour Grafana non plus).
#
# Expose aussi l'API Prometheus (port 9090) : lue par le moniteur externe
# Uptime Kuma (external-monitoring/uptime-kuma/) pour vérifier que le
# "battement de cœur" (infra/monitoring/rules/watchdog.yml) avance
# toujours, indépendamment du cluster qu'il observe.
resource "kubernetes_secret" "collab_gateway_wireguard" {
  metadata {
    name      = "collab-gateway-wireguard"
    namespace = "ci-cd"
  }

  data = {
    "wg0.conf" = <<-EOT
      [Interface]
      PrivateKey = ${base64decode(data.scaleway_secret_version.jenkins["collab_gateway_wireguard_key"].data)}
      Address = 10.10.40.2/24

      [Peer]
      PublicKey = ${var.relay_kapsule_wireguard_public_key}
      Endpoint = ${var.relay_kapsule_wan_endpoint}
      AllowedIPs = 10.10.40.0/24
      PersistentKeepalive = 25
    EOT
  }
}

resource "kubernetes_deployment" "collab_gateway" {
  metadata {
    name      = "collab-gateway"
    namespace = "ci-cd"
    labels = {
      app = "collab-gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "collab-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "collab-gateway"
        }
      }

      spec {
        container {
          name  = "collab-gateway"
          image = "alpine:3.20"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            set -eu
            apk add --no-cache wireguard-tools socat
            mkdir -p /etc/wireguard
            cp /etc/wireguard-secret/wg0.conf /etc/wireguard/wg0.conf
            chmod 600 /etc/wireguard/wg0.conf
            wg-quick up wg0
            socat TCP-LISTEN:8080,fork,reuseaddr,bind=10.10.40.2 TCP:jenkins.ci-cd.svc.cluster.local:8080 &
            socat TCP-LISTEN:3000,fork,reuseaddr,bind=10.10.40.2 TCP:monitoring-grafana.monitoring.svc.cluster.local:80 &
            socat TCP-LISTEN:9090,fork,reuseaddr,bind=10.10.40.2 TCP:monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090 &
            tail -f /dev/null
            EOT
          ]

          security_context {
            capabilities {
              add = ["NET_ADMIN"]
            }
          }

          volume_mount {
            name       = "wireguard-config"
            mount_path = "/etc/wireguard-secret"
            read_only  = true
          }
        }

        volume {
          name = "wireguard-config"
          secret {
            secret_name = kubernetes_secret.collab_gateway_wireguard.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [helm_release.jenkins]
}
