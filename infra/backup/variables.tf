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

variable "retention_days" {
  description = "Nombre de jours de rétention des sauvegardes dans le bucket"
  type        = number
  default     = 7
}
