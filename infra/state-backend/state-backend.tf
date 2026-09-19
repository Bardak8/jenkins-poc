resource "scaleway_object_bucket" "tfstate" {
  name   = "jenkins-poc-tfstate"
  region = var.region
}

resource "scaleway_iam_application" "tfstate" {
  name = "jenkins-poc-tfstate"
}

resource "scaleway_iam_policy" "tfstate" {
  name           = "jenkins-poc-tfstate"
  application_id = scaleway_iam_application.tfstate.id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = ["ObjectStorageFullAccess"]
  }
}

resource "scaleway_iam_api_key" "tfstate" {
  application_id = scaleway_iam_application.tfstate.id
  expires_at     = "2027-06-30T00:00:00Z"
}

resource "kubernetes_secret" "tfstate_credentials" {
  metadata {
    name      = "tfstate-credentials"
    namespace = "ci-cd"
  }

  data = {
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.tfstate.access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.tfstate.secret_key
  }
}
