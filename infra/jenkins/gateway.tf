resource "kubernetes_secret" "gateway_wireguard" {
  metadata {
    name      = "gateway-wireguard"
    namespace = "ci-cd"
  }

  data = {
    "wg0.conf" = <<-EOT
      [Interface]
      PrivateKey = ${var.gateway_wireguard_private_key}
      Address = 10.10.10.2/24

      [Peer]
      PublicKey = ${var.outillage_wireguard_public_key}
      Endpoint = ${var.outillage_wan_endpoint}
      AllowedIPs = 192.168.1.0/24, 10.10.10.0/24
      PersistentKeepalive = 25
    EOT
  }
}

resource "kubernetes_deployment" "gateway" {
  metadata {
    name      = "gateway"
    namespace = "ci-cd"
    labels = {
      app = "gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "gateway"
        }
      }

      spec {
        container {
          name  = "gateway"
          image = "alpine:3.20"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            set -eu
            apk add --no-cache wireguard-tools openssh-client socat
            mkdir -p /etc/wireguard
            cp /etc/wireguard-secret/wg0.conf /etc/wireguard/wg0.conf
            chmod 600 /etc/wireguard/wg0.conf
            wg-quick up wg0
            socat TCP-LISTEN:8006,fork,reuseaddr TCP:${var.proxmox_lan_ip}:8006 &
            socat TCP-LISTEN:9100,fork,reuseaddr TCP:192.168.1.5:9100 &
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
            secret_name = kubernetes_secret.gateway_wireguard.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "gateway" {
  metadata {
    name      = "gateway"
    namespace = "ci-cd"
  }

  spec {
    selector = {
      app = "gateway"
    }

    port {
      name        = "proxmox-api"
      port        = 8006
      target_port = 8006
    }

    port {
      name        = "node-exporter"
      port        = 9100
      target_port = 9100
    }
  }
}
