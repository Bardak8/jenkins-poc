resource "proxmox_virtual_environment_vm" "outillage" {
  name      = "outillage"
  node_name = var.proxmox_node
  vm_id     = var.outillage_vmid

  clone {
    vm_id = var.debian_template_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi0"
    size         = 8
  }

  network_device {
    bridge = var.lan_bridge
  }

  initialization {
    datastore_id = var.vm_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "admin"
      keys     = [var.ssh_public_key]
    }
  }

  started = true
  on_boot = true
}
