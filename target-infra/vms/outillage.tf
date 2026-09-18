# VM outillage — équivalent local de blagnac-dc-tools-02 dans le projet
# réel. Porte le tunnel WireGuard site-à-site vers Jenkins (PAS pfSense,
# voir la distinction faite avec l'utilisateur : le tunnel projet est
# porté par cette VM, pfSense ne fait que router/filtrer autour).
#
# Appliqué manuellement par Maxime, après pfSense (target-infra/pfsense/)
# et avant tout pipeline Jenkins — c'est cette VM qui doit exister et
# porter le tunnel pour que Jenkins puisse ensuite joindre le reste.

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
    dedicated = 1024
  }

  network_device {
    bridge = var.lan_bridge
  }

  initialization {
    user_account {
      username = "admin"
      keys     = [var.ssh_public_key]
    }
  }

  started = true
  on_boot = true
}
