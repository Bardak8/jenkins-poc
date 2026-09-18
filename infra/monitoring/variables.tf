variable "project_id" {
  description = "ID du projet Scaleway dédié et isolé au PoC (le même que le module jenkins/)."
  type        = string
}

variable "cluster_id" {
  description = "ID du cluster Kapsule existant (le même que le module jenkins/). Terraform ne fait que le référencer, jamais le créer ni le détruire."
  type        = string
}

variable "region" {
  description = "Région Scaleway."
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Zone Scaleway du pool de nœuds."
  type        = string
  default     = "fr-par-2"
}

variable "monitoring_chart_version" {
  description = "Version du chart Helm prometheus-community/kube-prometheus-stack."
  type        = string
  default     = "65.5.1"
}
