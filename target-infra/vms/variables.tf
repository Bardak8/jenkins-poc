variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox du KS-3. Depuis Jenkins, jointe à travers le tunnel WireGuard (IP privée du LAN pfSense) ; depuis le poste de Maxime pour la VM outillage, jointe directement (IP publique) tant que le tunnel n'existe pas encore."
  type        = string
}

variable "proxmox_insecure_tls" {
  type    = bool
  default = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "lan_bridge" {
  description = "Bridge Proxmox du réseau interne (LAN pfSense), même valeur que dans target-infra/pfsense/."
  type        = string
  default     = "vmbr1"
}

variable "ssh_public_key" {
  description = "Clé publique SSH injectée via cloud-init sur les VM créées ici (jamais la clé privée, jamais versionnée en clair au-delà de terraform.tfvars gitignoré)."
  type        = string
}

variable "debian_template_id" {
  description = "ID d'un template Proxmox Debian (cloud-init), utilisé pour cloner aussi bien la VM outillage que les VM de démo."
  type        = number
}

# --- VM outillage ---

variable "outillage_vmid" {
  type    = number
  default = 200
}

# --- VM(s) de démo ---

variable "demo_vm_count" {
  description = "Nombre de VM de démo à créer (pipeline Jenkins)."
  type        = number
  default     = 1
}

variable "demo_vmid_start" {
  description = "Premier ID de VM pour les VM de démo (incrémenté si demo_vm_count > 1)."
  type        = number
  default     = 300
}
