variable "project_id" {
  description = "ID du projet Scaleway dédié et isolé au PoC (créé manuellement en amont, jamais un projet existant type Bamboo/Platform/Staging/Datahub)."
  type        = string
}

variable "cluster_id" {
  description = "ID du cluster Kapsule existant (créé manuellement via la console, dans le projet isolé ci-dessus). Terraform ne fait que le référencer, jamais le créer ni le détruire."
  type        = string
}

variable "region" {
  description = "Région Scaleway."
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Zone Scaleway du pool de nœuds (PARIS 2 choisi dans la console)."
  type        = string
  default     = "fr-par-2"
}

variable "jenkins_chart_version" {
  description = "Version du chart Helm jenkinsci/jenkins. 5.9.56 (appVersion 2.568.3) choisie car les plugins installés sans version épinglée (installPlugins) résolvent vers leurs dernières versions, qui exigent un cœur Jenkins récent (jusqu'à 2.504.3 constaté) — le chart 5.7.7 par défaut embarquait un Jenkins 2.462.3 trop ancien, cause du crash au premier apply."
  type        = string
  default     = "5.9.56"
}

variable "jenkins_admin_password_secret_name" {
  description = "Nom du Secret Kubernetes (créé hors Terraform, jamais en clair dans ce dépôt) portant le mot de passe admin initial de Jenkins."
  type        = string
  default     = "jenkins-admin-credentials"
}

variable "git_repo_url" {
  description = "URL du dépôt Git de ce PoC (une fois poussé sur un remote), utilisée par le seed job pour définir le pipeline en SCM. Placeholder tant que le dépôt n'est pas encore poussé."
  type        = string
  default     = "https://github.com/CHANGEME/jenkins-poc.git"
}

variable "git_credentials_id" {
  description = "Identifiant Jenkins (credential) du token Git, créé hors Terraform via un Secret Kubernetes monté dans JCasC — jamais en clair ici."
  type        = string
  default     = "git-poc-token"
}

variable "jenkins_url" {
  description = "URL publique du contrôleur Jenkins, une fois connue (IP du LoadBalancer ou DNS). Laisser vide au premier apply, renseigner et ré-appliquer ensuite : classique problème d'œuf et de poule avec un LoadBalancer dont l'IP n'est connue qu'après création."
  type        = string
  default     = ""
}
