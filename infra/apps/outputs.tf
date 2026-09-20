output "registry_endpoint" {
  description = "Endpoint du Container Registry Scaleway, à renseigner dans infra/jenkins/terraform.tfvars (scw_registry_endpoint)"
  value       = scaleway_registry_namespace.apps.endpoint
}

output "next_step" {
  description = "Rappel de la procédure post-apply"
  value       = "1) Copier registry_endpoint dans infra/jenkins/terraform.tfvars (scw_registry_endpoint), renseigner aussi scaleway_secret_key, puis ré-appliquer infra/jenkins/ pour créer le secret de registre. 2) Adapter le Jenkinsfile d'Isaac-Api pour pousser vers registry_endpoint (voir instructions fournies). 3) Ajouter le job 'deploy-isaac-app' au seed job Jenkins et lancer un premier build manuel pour sortir les pods d'ImagePullBackOff. 4) Si isaac_hostname est renseigné, pointer le DNS de ce sous-domaine vers la même IP que l'Ingress (infra/ingress/ output ingress_public_ip)."
}
