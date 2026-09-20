# Domaine dédié à l'envoi de mail (sous-domaine pour ne pas interférer
# avec les enregistrements DNS existants de obrypoc.fr).
resource "scaleway_tem_domain" "alerts" {
  name       = "mail.obrypoc.fr"
  accept_tos = true
}

resource "scaleway_iam_application" "alerting_smtp" {
  name = "jenkins-poc-alerting-smtp"
}

resource "scaleway_iam_policy" "alerting_smtp" {
  name           = "jenkins-poc-alerting-smtp"
  application_id = scaleway_iam_application.alerting_smtp.id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = ["TransactionalEmailEmailSmtpCreate"]
  }
}

resource "scaleway_iam_api_key" "alerting_smtp" {
  application_id = scaleway_iam_application.alerting_smtp.id
  expires_at     = "2027-06-30T00:00:00Z"
}

output "alerting_smtp_host" {
  value = "${scaleway_tem_domain.alerts.smtp_host}:${scaleway_tem_domain.alerts.smtp_port}"
}

output "alerting_smtp_username" {
  value = scaleway_tem_domain.alerts.smtps_auth_user
}

output "alerting_smtp_password" {
  value     = scaleway_iam_api_key.alerting_smtp.secret_key
  sensitive = true
}

output "alerting_dns_records_to_add" {
  description = "Enregistrements DNS à ajouter manuellement (hors Terraform, cf README) pour valider le domaine d'envoi mail-.obrypoc.fr"
  value = {
    spf   = scaleway_tem_domain.alerts.spf_config
    dkim  = "${scaleway_tem_domain.alerts.dkim_name} -> ${scaleway_tem_domain.alerts.dkim_config}"
    mx    = scaleway_tem_domain.alerts.mx_config
    dmarc = "${scaleway_tem_domain.alerts.dmarc_name} -> ${scaleway_tem_domain.alerts.dmarc_config}"
  }
}
