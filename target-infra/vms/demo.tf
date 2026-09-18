# VM(s) de démonstration — la cible réelle du pipeline Jenkins
# (`deploy-monitoring-vm`, voir infra/jenkins/jobs/seed-job.groovy.tpl).
# C'est cette ressource, et elle seule, que le pipeline applique : la
# preuve que Jenkins sert bien à déployer quelque chose, sur un
# environnement distinct de celui qui l'héberge.

resource "proxmox_virtual_environment_vm" "demo" {
  count = var.demo_vm_count

  name      = "demo-${count.index}"
  node_name = var.proxmox_node
  vm_id     = var.demo_vmid_start + count.index

  clone {
    vm_id = var.debian_template_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
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
