output "grafana_admin_password_command" {
  description = "Commande pour récupérer le mot de passe admin Grafana généré par le chart."
  value       = "kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
}
