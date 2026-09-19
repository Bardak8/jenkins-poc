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

variable "jenkins_admin_password_secret_name" {
  description = "Nom du Secret Kubernetes portant le mot de passe admin Jenkins"
  type        = string
  default     = "jenkins-admin-credentials"
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
  description = "Type du service Kubernetes exposant Jenkins"
  type        = string
  default     = "ClusterIP"
}

variable "jenkins_url" {
  description = "URL publique du contrôleur Jenkins"
  type        = string
  default     = ""
}
