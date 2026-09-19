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
  description = "Zone Scaleway par défaut du provider"
  type        = string
  default     = "fr-par-2"
}

variable "cluster_id" {
  description = "ID du cluster Kapsule existant"
  type        = string
}

variable "node_type" {
  description = "Type d'instance des nœuds"
  type        = string
  default     = "dev1_l"
}

variable "ha_enabled" {
  description = "Ajoute 2 pools supplémentaires (fr-par-1, fr-par-3) pour une redondance multi-zone. Sans ce flag : un seul nœud dans fr-par-2 (état actuel)."
  type        = bool
  default     = false
}
