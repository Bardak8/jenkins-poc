variable "project_id" {
  description = "ID du projet Scaleway isolé"
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

variable "cluster_id" {
  description = "ID du cluster Kapsule existant"
  type        = string
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
