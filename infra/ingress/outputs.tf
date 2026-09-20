data "kubernetes_service" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [helm_release.ingress_nginx]
}

output "ingress_public_ip" {
  description = "IP publique du LoadBalancer Scaleway créé pour ingress-nginx — c'est celle-ci qu'il faut mettre dans le DNS. Attention : allouée dynamiquement par le cloud-controller-manager (en zone fr-par-1, quelle que soit la zone du cluster), elle change si le Service/LB est détruit puis recréé."
  value       = try(data.kubernetes_service.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].ip, "")
}

output "next_step" {
  description = "Rappel de la procédure post-apply"
  value       = "1) Récupérer ingress_public_ip (peut prendre 1-2 min à apparaître). 2) Créer l'enregistrement DNS A vers cette IP. 3) Vérifier `kubectl get pods -n cert-manager` puis repasser enable_cluster_issuer=true et ré-appliquer. 4) Appliquer infra/jenkins avec jenkins_service_type=ClusterIP et jenkins_hostname renseigné."
}
