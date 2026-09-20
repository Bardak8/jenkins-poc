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

variable "ingress_nginx_chart_version" {
  description = "Version du chart Helm ingress-nginx"
  type        = string
  default     = "4.11.3"
}

variable "cert_manager_chart_version" {
  description = "Version du chart Helm cert-manager (jetstack)"
  type        = string
  default     = "v1.16.2"
}

variable "letsencrypt_email" {
  description = "Email de contact pour les certificats Let's Encrypt (expiration, abus)"
  type        = string
}

variable "enable_cluster_issuer" {
  description = "Créer le ClusterIssuer Let's Encrypt. À laisser à false au premier apply (les CRD cert-manager n'existent pas encore), puis repasser à true et ré-appliquer."
  type        = bool
  default     = false
}
