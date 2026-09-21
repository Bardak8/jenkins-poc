output "cluster_id" {
  description = "ID du cluster Kapsule référencé"
  value       = data.scaleway_k8s_cluster.poc.id
}

output "kubeconfig" {
  description = "Kubeconfig du cluster"
  value       = data.scaleway_k8s_cluster.poc.kubeconfig[0].config_file
  sensitive   = true
}

output "jenkins_namespace" {
  description = "Namespace Kubernetes où Jenkins est déployé"
  value       = helm_release.jenkins.namespace
}

output "next_step" {
  description = "Rappel de la procédure post-apply"
  value       = "Jenkins reste en ClusterIP, jamais exposé publiquement (jenkins_hostname doit rester vide). Grafana pareil (grafana_hostname doit rester vide dans infra/monitoring). Accès uniquement via le VPN du relais (infra/relay/) : une fois collab-gateway up, jenkins_url=http://jenkins.obrypoc.fr:8080 (DNS -> 10.10.40.2) et grafana=http://grafana.obrypoc.fr:3000 (DNS -> 10.10.40.2 aussi), IP tunnel du pod collab-gateway, jamais joignable hors VPN."
}
