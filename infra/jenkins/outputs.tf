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
  value       = "Récupérer l'IP du service jenkins (kubectl get svc -n ci-cd), la renseigner dans var.jenkins_url, puis relancer terraform apply pour figer l'URL dans JCasC."
}
