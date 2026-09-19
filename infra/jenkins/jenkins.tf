locals {
  seed_job_script = templatefile("${path.module}/jobs/seed-job.groovy.tpl", {
    git_repo_url       = var.git_repo_url
    git_credentials_id = var.git_credentials_id
  })

  jenkins_casc = templatefile("${path.module}/jcasc/jenkins-casc.yaml.tpl", {
    seed_job_script = local.seed_job_script
  })
}

resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.jenkins_chart_version
  namespace        = "ci-cd"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        numExecutors = 2
        jenkinsUrl   = var.jenkins_url
        serviceType  = var.jenkins_service_type
        admin = {
          username = "admin"
          password = var.jenkins_admin_password
        }
        installPlugins = [
          "configuration-as-code",
          "job-dsl",
          "git",
          "workflow-aggregator",
          "credentials-binding",
          "kubernetes",
          "kubernetes-credentials-provider",
        ]
        JCasC = {
          configScripts = {
            poc-config = local.jenkins_casc
          }
        }
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }
      serviceAccount = {
        create = true
      }
      persistence = {
        existingClaim = "jenkins-longhorn"
      }
    })
  ]

  depends_on = [data.scaleway_k8s_cluster.poc]
}
