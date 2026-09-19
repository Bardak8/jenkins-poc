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
