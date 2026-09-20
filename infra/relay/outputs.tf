output "relay_public_ip" {
  description = "IP publique du VPS relais (endpoint pour la patte laptop, wg0, port 51820)"
  value       = scaleway_instance_ip.relay.address
}

output "next_step" {
  description = "Rappel de la procédure post-apply"
  value       = "1) Configurer le client WireGuard du poste de travail avec Endpoint=<relay_public_ip>:51820. 2) Créer le pod collab-gateway (infra/jenkins/) avec pour peer Endpoint=<relay_public_ip>:51821. 3) Pointer jenkins.obrypoc.fr en DNS vers 10.10.40.2 (IP tunnel du pod, jamais joignable hors VPN)."
}
