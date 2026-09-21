# Même principe que infra/apps/secrets-manager.tf : les secrets du module
# Jenkins (clés WireGuard, token Proxmox, identifiants SMTP, clé de
# déploiement) passent par Scaleway Secret Manager plutôt que d'être
# seulement des variables tfvars en clair. La valeur initiale vient encore
# des variables existantes pour ne rien faire dériver de ce qui tourne
# déjà ; toute rotation future se fait via une nouvelle
# scaleway_secret_version, jamais en éditant le tfvars.
#
# Les noms (jenkins_secret_names) et les valeurs (jenkins_secret_values)
# sont séparés exprès : Terraform interdit qu'une valeur sensible serve de
# clé de for_each, seuls les noms littéraux peuvent jouer ce rôle.
locals {
  # nonsensitive() : le résultat n'est jamais qu'une liste de NOMS littéraux
  # ("alerting_smtp_username", pas sa valeur). Seule la condition qui décide
  # de leur présence touche une variable sensible, ce qui suffit à Terraform
  # pour teinter tout le local par prudence ; on lève cette teinte ici en
  # connaissance de cause.
  jenkins_secret_names = nonsensitive(toset(concat(
    [
      "proxmox_api_token",
      "collab_gateway_wireguard_key",
      "gateway_wireguard_key",
      "deploy_wireguard_key",
      "deploy_ssh_key",
    ],
    var.alerting_smtp_password != "" ? ["alerting_smtp_username", "alerting_smtp_password"] : [],
    var.scaleway_secret_key != "" && var.scw_registry_endpoint != "" ? ["scw_registry_secret_key"] : []
  )))

  jenkins_secret_values = {
    proxmox_api_token            = var.proxmox_api_token
    collab_gateway_wireguard_key = var.collab_gateway_wireguard_private_key
    gateway_wireguard_key        = var.gateway_wireguard_private_key
    deploy_wireguard_key         = var.deploy_wireguard_private_key
    deploy_ssh_key               = file(pathexpand(var.deploy_ssh_private_key_path))
    alerting_smtp_username       = var.alerting_smtp_username
    alerting_smtp_password       = var.alerting_smtp_password
    scw_registry_secret_key      = var.scaleway_secret_key
  }
}

resource "scaleway_secret" "jenkins" {
  for_each    = local.jenkins_secret_names
  name        = "jenkins-${replace(each.value, "_", "-")}"
  description = "Secret pipeline Jenkins : ${each.value}"
}

resource "scaleway_secret_version" "jenkins" {
  for_each  = local.jenkins_secret_names
  secret_id = scaleway_secret.jenkins[each.value].id
  data      = local.jenkins_secret_values[each.value]
}

data "scaleway_secret_version" "jenkins" {
  for_each  = local.jenkins_secret_names
  secret_id = scaleway_secret.jenkins[each.value].id
  revision  = "latest"

  depends_on = [scaleway_secret_version.jenkins]
}
