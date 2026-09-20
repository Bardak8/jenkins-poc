# Autorise le ServiceAccount du contrôleur Jenkins (namespace ci-cd,
# créé par le chart Helm dans infra/jenkins/) à déployer dans apps.
# Les pods de build lancés par Jenkins (agent kubernetes) héritent de ce
# ServiceAccount via serviceAccountName: jenkins dans le Jenkinsfile.
resource "kubernetes_role" "jenkins_deploy_apps" {
  metadata {
    name      = "jenkins-deploy-apps"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_deploy_apps" {
  metadata {
    name      = "jenkins-deploy-apps"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_deploy_apps.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = "ci-cd"
  }
}
