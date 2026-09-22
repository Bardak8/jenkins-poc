variable "project_id" {
  description = "ID du projet Scaleway isolé"
  type        = string
}

variable "cluster_id" {
  description = "ID du cluster Kapsule existant"
  type        = string
}

variable "region" {
  description = "Région Scaleway"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Zone Scaleway"
  type        = string
  default     = "fr-par-2"
}

variable "jenkins_chart_version" {
  description = "Version du chart Helm jenkinsci/jenkins"
  type        = string
  default     = "5.9.56"
}

variable "longhorn_chart_version" {
  description = "Version du chart Helm Longhorn"
  type        = string
  default     = "1.7.2"
}

variable "replica_count" {
  description = "Nombre de réplicas par volume Longhorn (un par nœud disponible)"
  type        = number
  default     = 3
}

variable "jenkins_admin_password" {
  description = "Mot de passe admin Jenkins, fixe pour survivre à une reconstruction"
  type        = string
  sensitive   = true
}

variable "git_repo_url" {
  description = "URL du dépôt Git"
  type        = string
  default     = "https://github.com/CHANGEME/jenkins-poc.git"
}

variable "git_credentials_id" {
  description = "ID du credential Jenkins pour le token Git"
  type        = string
  default     = "git-poc-token"
}

variable "collab_gateway_wireguard_private_key" {
  description = "Clé privée WireGuard du pod collab-gateway (accès humain vers Jenkins)"
  type        = string
  sensitive   = true
}

variable "relay_kapsule_wireguard_public_key" {
  description = "Clé publique WireGuard du relais Scaleway côté patte Kapsule (wg1, infra/relay/)"
  type        = string
}

variable "relay_kapsule_wan_endpoint" {
  description = "Endpoint du relais pour la patte Kapsule (host:port), ex: <relay_public_ip>:51821"
  type        = string
}

variable "isaac_git_repo_url" {
  description = "URL du dépôt Git d'Isaac-Api (app de démo déployée dans le namespace apps)"
  type        = string
  default     = "https://github.com/Bardak8/Isaac-Api.git"
}

variable "isaac_webhook_token" {
  description = "Token partagé pour le webhook GitHub 'release' d'Isaac-Api (Generic Webhook Trigger). Doit être identique côté config du webhook GitHub."
  type        = string
  sensitive   = true
}

variable "gateway_wireguard_private_key" {
  description = "Clé privée WireGuard de la passerelle"
  type        = string
  sensitive   = true
}

variable "outillage_wireguard_public_key" {
  description = "Clé publique WireGuard de la VM outillage"
  type        = string
}

variable "outillage_wan_endpoint" {
  description = "Endpoint WAN du tunnel (host:port)"
  type        = string
  default     = "51.161.144.5:51820"
}

variable "proxmox_lan_ip" {
  description = "IP LAN de Proxmox (relayée par le pod gateway)"
  type        = string
}

variable "deploy_wireguard_private_key" {
  description = "Clé privée WireGuard du tunnel éphémère de déploiement"
  type        = string
  sensitive   = true
}

variable "deploy_ssh_private_key_path" {
  description = "Chemin local vers la clé privée SSH de déploiement"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API Proxmox (USER@REALM!TOKENID=UUID)"
  type        = string
  sensitive   = true
}

variable "jenkins_service_type" {
  description = "Type du service Kubernetes exposant Jenkins. ClusterIP une fois l'Ingress (infra/ingress/) en place ; LoadBalancer uniquement si l'on veut exposer Jenkins directement, sans passer par l'Ingress."
  type        = string
  default     = "ClusterIP"
}

variable "jenkins_url" {
  description = "URL publique du contrôleur Jenkins (ex: https://jenkins.obrypoc.fr)"
  type        = string
  default     = ""
}

variable "jenkins_hostname" {
  description = "Nom d'hôte utilisé par l'Ingress pour router vers Jenkins (ex: jenkins.obrypoc.fr). Laisser vide pour ne pas créer d'Ingress."
  type        = string
  default     = ""
}

variable "scaleway_secret_key" {
  description = "Clé secrète API Scaleway, utilisée par kaniko pour pousser les images vers le Container Registry (infra/apps/)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "scw_registry_endpoint" {
  description = "Endpoint du Container Registry Scaleway (sortie registry_endpoint de infra/apps/), ex: rg.fr-par.scw.cloud/jenkins-poc-apps"
  type        = string
  default     = ""
}

variable "alerting_smtp_username" {
  description = "Utilisateur SMTP (sortie alerting_smtp_username de infra/monitoring/)"
  type        = string
  default     = ""
}

variable "alerting_smtp_password" {
  description = "Mot de passe SMTP (sortie alerting_smtp_password de infra/monitoring/)"
  type        = string
  sensitive   = true
  default     = ""
}
