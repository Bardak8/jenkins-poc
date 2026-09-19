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
  description = "Type d'instance du pool existant (fr-par-2)"
  type        = string
  default     = "dev1_l"
}

variable "ha_enabled" {
  description = "Ajoute les pools de ha_zones pour une redondance multi-zone. Sans ce flag : un seul nœud dans fr-par-2 (état actuel)."
  type        = bool
  default     = false
}

variable "ha_zones" {
  description = "Zones supplémentaires et type d'instance associé (le catalogue d'instances diffère par zone chez Scaleway, dev1_l n'existe pas partout)"
  type        = map(string)
  default = {
    "fr-par-1" = "dev1_l"
    "fr-par-3" = "GP1-XS"
  }
}
