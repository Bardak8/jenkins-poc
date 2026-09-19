resource "scaleway_k8s_pool" "primary" {
  cluster_id             = "${var.region}/${var.cluster_id}"
  name                   = "pool-par-2-great-maxwell"
  node_type              = var.node_type
  zone                   = "fr-par-2"
  size                   = 1
  min_size               = 1
  max_size               = 1
  autoscaling            = false
  autohealing            = true
  container_runtime      = "containerd"
  root_volume_type       = "sbs_5k"
  root_volume_size_in_gb = 20
}

resource "scaleway_k8s_pool" "ha" {
  for_each = var.ha_enabled ? var.ha_zones : {}

  cluster_id             = "${var.region}/${var.cluster_id}"
  name                   = "pool-${each.key}-ha"
  node_type              = each.value
  zone                   = each.key
  size                   = 1
  min_size               = 1
  max_size               = 1
  autoscaling            = false
  autohealing            = true
  container_runtime      = "containerd"
  root_volume_type       = "sbs_5k"
  root_volume_size_in_gb = 20
}
