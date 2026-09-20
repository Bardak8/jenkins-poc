locals {
  cloud_init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    relay_laptop_private_key            = var.relay_laptop_private_key
    laptop_wireguard_public_key         = var.laptop_wireguard_public_key
    relay_kapsule_private_key           = var.relay_kapsule_private_key
    collab_gateway_wireguard_public_key = var.collab_gateway_wireguard_public_key
    relay_ovh_private_key               = var.relay_ovh_private_key
    pfsense_wireguard_public_key        = var.pfsense_wireguard_public_key
    pfsense_collab_wan_endpoint         = var.pfsense_collab_wan_endpoint
  })
}

resource "scaleway_instance_ip" "relay" {}

resource "scaleway_instance_server" "relay" {
  type  = var.instance_type
  image = var.instance_image
  ip_id = scaleway_instance_ip.relay.id

  user_data = {
    cloud-init = local.cloud_init
  }
}
