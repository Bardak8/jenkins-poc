terraform {
  required_version = ">= 1.15"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Même principe que target-infra/pfsense/ : credentials en variables
# d'environnement (PROXMOX_VE_API_TOKEN), jamais en dur ici.
#
# Deux usages distincts de ce module, voir README :
#  - la VM outillage (WireGuard) : appliquée manuellement par Maxime,
#    une fois pfSense en place (bootstrap réseau, avant que Jenkins
#    puisse joindre quoi que ce soit ici) ;
#  - la ou les VM de démo : appliquées par Jenkins depuis son pipeline,
#    une fois le tunnel WireGuard établi.
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure_tls
}
