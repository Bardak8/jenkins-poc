resource "kubernetes_role" "jenkins_credentials" {
  metadata {
    name      = "jenkins-credentials"
    namespace = "ci-cd"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_credentials" {
  metadata {
    name      = "jenkins-credentials"
    namespace = "ci-cd"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_credentials.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = "ci-cd"
  }

  depends_on = [helm_release.jenkins]
}
