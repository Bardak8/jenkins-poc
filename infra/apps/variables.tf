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

variable "isaac_db_password" {
  description = "Mot de passe Postgres pour la base isaac-fansite"
  type        = string
  sensitive   = true
}

variable "isaac_hostname" {
  description = "Nom d'hôte utilisé par l'Ingress pour router vers isaac-fansite (ex: isaac.obrypoc.fr). Laisser vide pour ne pas créer d'Ingress (accès par kubectl port-forward uniquement)."
  type        = string
  default     = ""
}
