# Un deuxième point d'entrée public, dans une zone différente du premier.
#
# Le Load Balancer principal (ingress.tf) est géré par le
# cloud-controller-manager de Kapsule via le Service Kubernetes
# "LoadBalancer" : il est verrouillé en fr-par-1, quelle que soit la zone
# du cluster (voir le commentaire de scaleway_lb_ip.ingress). Ce
# mécanisme ne permet donc pas d'obtenir un deuxième LB ailleurs.
#
# Ce fichier provisionne un second Load Balancer en direct, hors du
# contrôle du CCM, dans une autre zone. Il route vers les mêmes pods
# ingress-nginx via un Service NodePort dédié (additif : le Service
# LoadBalancer existant n'est pas touché). Bascule entre les deux :
# manuelle aujourd'hui (scripts/dns-failover.sh), en changeant
# l'enregistrement DNS vers l'IP du LB sain.

resource "kubernetes_service" "ingress_nginx_nodeport" {
  metadata {
    name      = "ingress-nginx-ha-nodeport"
    namespace = "ingress-nginx"
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/instance"  = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
      node_port   = 30080
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = "https"
      node_port   = 30443
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.ingress_nginx]
}

# IP et LB dans fr-par-2 : différente de fr-par-1 (LB principal), et zone
# où vit le nœud primaire du cluster (pool.tf), pour une latence minimale
# vers ce nœud tant que les pools HA (fr-par-1/fr-par-3) sont éteints.
resource "scaleway_lb_ip" "ingress_secondary" {
  zone = "fr-par-2"
}

resource "scaleway_lb" "ingress_secondary" {
  zone  = "fr-par-2"
  ip_id = scaleway_lb_ip.ingress_secondary.id
  type  = "LB-S"
}

# Cible dynamiquement les nœuds actuellement vivants du cluster, quelle
# que soit leur zone : le backend suit le pool réel, HA activé ou non.
#
# IP publique du nœud, pas l'IP privée : le cluster et ce LB ne partagent
# aucun Private Network Scaleway, donc le LB ne peut pas router vers l'IP
# privée (172.16.x.x). Vérifié en direct : le NodePort répond
# correctement sur l'IP publique (le security group ne laisse passer que
# 30080/30443, rien d'autre n'est exposé par ce biais).
data "kubernetes_nodes" "all" {}

locals {
  node_internal_ips = [
    for node in data.kubernetes_nodes.all.nodes : [
      for addr in node.status[0].addresses : addr.address
      if addr.type == "ExternalIP"
    ][0]
  ]
}

resource "scaleway_lb_backend" "ingress_https" {
  lb_id            = scaleway_lb.ingress_secondary.id
  name             = "ingress-https"
  forward_protocol = "tcp"
  forward_port     = 30443
  server_ips       = local.node_internal_ips

  health_check_tcp {}
}

resource "scaleway_lb_backend" "ingress_http" {
  lb_id            = scaleway_lb.ingress_secondary.id
  name             = "ingress-http"
  forward_protocol = "tcp"
  forward_port     = 30080
  server_ips       = local.node_internal_ips

  health_check_tcp {}
}

resource "scaleway_lb_frontend" "ingress_https" {
  lb_id        = scaleway_lb.ingress_secondary.id
  backend_id   = scaleway_lb_backend.ingress_https.id
  name         = "ingress-https"
  inbound_port = 443
}

resource "scaleway_lb_frontend" "ingress_http" {
  lb_id        = scaleway_lb.ingress_secondary.id
  backend_id   = scaleway_lb_backend.ingress_http.id
  name         = "ingress-http"
  inbound_port = 80
}

# Le security group par défaut de Kapsule ("Kapsule default security
# group") a une politique d'entrée "drop" sans aucune règle
# d'autorisation : par défaut, rien n'atteint les NodePort du nœud, y
# compris le trafic légitime du LB de secours ci-dessus.
#
# Recherché par nom plutôt que par ID en dur : ce security group est créé
# par Kapsule lui-même (pas par ce Terraform) et reçoit un nouvel ID à
# chaque destroy/apply complet du cluster (scénario "scratch build"). Une
# référence en dur serait orpheline après une reconstruction.
data "scaleway_instance_security_group" "kapsule_default" {
  name = "Kapsule default security group"
  zone = "fr-par-2"
}

resource "scaleway_instance_security_group_rules" "kapsule_nodeport" {
  security_group_id = data.scaleway_instance_security_group.kapsule_default.id

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 30080
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 30443
  }
}

output "ingress_secondary_ip" {
  value       = scaleway_lb_ip.ingress_secondary.ip_address
  description = "IP du Load Balancer de secours (fr-par-2). Bascule manuelle : repointer le DNS (isaac.obrypoc.fr, grafana.obrypoc.fr) vers cette IP si le LB principal (fr-par-1) est indisponible."
}
