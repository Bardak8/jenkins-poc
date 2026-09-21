# Le mot de passe applicatif isaac-postgres vit désormais dans Scaleway
# Secret Manager plutôt que d'être seulement dispersé dans un fichier
# tfvars. Ça centralise le stockage et l'audit d'accès côté Scaleway.
# La valeur initiale vient encore de var.isaac_db_password (pour ne pas
# faire dériver le mot de passe d'un cluster déjà initialisé), mais une
# rotation se fait désormais en créant une nouvelle scaleway_secret_version,
# jamais en éditant le tfvars.
resource "scaleway_secret" "isaac_db_password" {
  name        = "isaac-db-password"
  description = "Mot de passe applicatif isaac-postgres"
}

resource "scaleway_secret_version" "isaac_db_password" {
  secret_id = scaleway_secret.isaac_db_password.id
  data      = var.isaac_db_password
}

data "scaleway_secret_version" "isaac_db_password" {
  secret_id = scaleway_secret.isaac_db_password.id
  revision  = "latest"

  depends_on = [scaleway_secret_version.isaac_db_password]
}
