terraform {
  required_version = ">= 1.15"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.50"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }
}

provider "scaleway" {
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}

provider "helm" {
  kubernetes {
    host                   = data.scaleway_k8s_cluster.poc.kubeconfig[0].host
    token                  = data.scaleway_k8s_cluster.poc.kubeconfig[0].token
    cluster_ca_certificate = base64decode(data.scaleway_k8s_cluster.poc.kubeconfig[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = data.scaleway_k8s_cluster.poc.kubeconfig[0].host
  token                  = data.scaleway_k8s_cluster.poc.kubeconfig[0].token
  cluster_ca_certificate = base64decode(data.scaleway_k8s_cluster.poc.kubeconfig[0].cluster_ca_certificate)
}
