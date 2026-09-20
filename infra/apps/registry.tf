resource "scaleway_registry_namespace" "apps" {
  name      = "jenkins-poc-apps"
  is_public = false
}

# Jenkins pousse ses images buildées ici via kaniko. Le pod de build a
# besoin d'un docker config.json pointant sur ce registre : voir le
# secret "scw-registry-credentials" créé côté infra/jenkins (ou à créer
# manuellement, voir output "next_step").
