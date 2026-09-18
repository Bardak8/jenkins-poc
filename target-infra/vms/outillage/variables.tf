variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox"
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
  description = "Bridge Proxmox du réseau interne"
  type        = string
  default     = "vmbr1"
}

variable "ssh_public_key" {
  description = "Clé publique SSH injectée via cloud-init"
  type        = string
}

variable "vm_datastore_id" {
  description = "Storage Proxmox pour les disques"
  type        = string
  default     = "local"
}

variable "debian_template_id" {
  description = "ID du template Proxmox Debian cloud-init"
  type        = number
}

variable "outillage_vmid" {
  type    = number
  default = 200
}
