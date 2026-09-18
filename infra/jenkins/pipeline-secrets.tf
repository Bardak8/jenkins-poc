resource "kubernetes_secret" "deploy_wireguard" {
  metadata {
    name      = "deploy-wireguard"
    namespace = "ci-cd"
  }

  data = {
    "wg0.conf" = <<-EOT
      [Interface]
      PrivateKey = ${var.deploy_wireguard_private_key}
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
    "id_ed25519" = file(pathexpand(var.deploy_ssh_private_key_path))
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
    text = var.proxmox_api_token
  }
}
