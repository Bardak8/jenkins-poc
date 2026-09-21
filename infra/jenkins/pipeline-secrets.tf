resource "kubernetes_secret" "deploy_wireguard" {
  metadata {
    name      = "deploy-wireguard"
    namespace = "ci-cd"
  }

  data = {
    "wg0.conf" = <<-EOT
      [Interface]
      PrivateKey = ${base64decode(data.scaleway_secret_version.jenkins["deploy_wireguard_key"].data)}
      Address = 10.10.10.3/24

      [Peer]
      PublicKey = ${var.outillage_wireguard_public_key}
      Endpoint = ${var.outillage_wan_endpoint}
      AllowedIPs = 192.168.1.0/24
      PersistentKeepalive = 25
    EOT
  }
}

resource "kubernetes_secret" "deploy_ssh_key" {
  metadata {
    name      = "deploy-ssh-key"
    namespace = "ci-cd"
  }

  data = {
    "id_ed25519" = base64decode(data.scaleway_secret_version.jenkins["deploy_ssh_key"].data)
  }
}

resource "kubernetes_secret" "scw_registry_credentials" {
  count = var.scaleway_secret_key != "" && var.scw_registry_endpoint != "" ? 1 : 0

  metadata {
    name      = "scw-registry-credentials"
    namespace = "ci-cd"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        # Registre Scaleway : login libre, mot de passe = clé secrète API.
        # À vérifier contre la doc Scaleway Container Registry au moment
        # de l'apply (le format d'auth peut évoluer).
        (split("/", var.scw_registry_endpoint)[0]) = {
          auth = base64encode("nologin:${base64decode(data.scaleway_secret_version.jenkins["scw_registry_secret_key"].data)}")
        }
      }
    })
  }
}

resource "kubernetes_secret" "proxmox_api_token" {
  metadata {
    name      = "proxmox-api-token"
    namespace = "ci-cd"
    labels = {
      "jenkins.io/credentials-type" = "secretText"
    }
    annotations = {
      "jenkins.io/credentials-description" = "Token API Proxmox (target-infra/vms)"
    }
  }

  data = {
    text = base64decode(data.scaleway_secret_version.jenkins["proxmox_api_token"].data)
  }
}

resource "kubernetes_secret" "alerting_smtp" {
  count = var.alerting_smtp_password != "" ? 1 : 0

  metadata {
    name      = "alerting-smtp"
    namespace = "ci-cd"
    labels = {
      "jenkins.io/credentials-type" = "usernamePassword"
    }
    annotations = {
      "jenkins.io/credentials-description" = "SMTP alerting (stack Prometheus/Alertmanager demo-0)"
    }
  }

  data = {
    username = base64decode(data.scaleway_secret_version.jenkins["alerting_smtp_username"].data)
    password = base64decode(data.scaleway_secret_version.jenkins["alerting_smtp_password"].data)
  }
}
