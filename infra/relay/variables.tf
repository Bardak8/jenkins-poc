variable "project_id" {
  description = "ID du projet Scaleway isolé"
  type        = string
}

variable "region" {
  description = "Région Scaleway"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Zone Scaleway"
  type        = string
  default     = "fr-par-2"
}

variable "instance_type" {
  description = "Type d'instance Scaleway pour le relais WireGuard"
  type        = string
  default     = "DEV1-M"
}

variable "instance_image" {
  description = "Image Scaleway (nom ou UUID)"
  type        = string
  default     = "ubuntu_jammy"
}

# --- Patte 1 : laptop (collaborateur) <-> relais ---

variable "relay_laptop_private_key" {
  description = "Clé privée WireGuard du relais pour la patte laptop (wg0)"
  type        = string
  sensitive   = true
}

variable "laptop_wireguard_public_key" {
  description = "Clé publique WireGuard du poste de travail (patte laptop <-> relais)"
  type        = string
}

# --- Patte 2 : relais <-> pod Kapsule (accès Jenkins) ---

variable "relay_kapsule_private_key" {
  description = "Clé privée WireGuard du relais pour la patte Kapsule (wg1)"
  type        = string
  sensitive   = true
}

variable "collab_gateway_wireguard_public_key" {
  description = "Clé publique WireGuard du pod collab-gateway (namespace ci-cd), qui compose vers le relais"
  type        = string
}

# --- Patte 3 : relais <-> pfSense (accès Proxmox), réutilise la paire "collaborateur" existante ---

variable "relay_ovh_private_key" {
  description = "Clé privée WireGuard côté relais pour la patte OVH (wg2). Réutilise wireguard/collaborateur/privatekey (déjà connue de pfSense), aucun changement pfSense nécessaire."
  type        = string
  sensitive   = true
}

variable "pfsense_wireguard_public_key" {
  description = "Clé publique WireGuard de pfSense (VPN_COLLAB), déjà configurée côté OVH"
  type        = string
}

variable "pfsense_collab_wan_endpoint" {
  description = "Endpoint WAN du VPN_COLLAB sur pfSense (host:port), ex: 51.161.144.5:51821"
  type        = string
}
