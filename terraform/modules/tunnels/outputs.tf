output "dev_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.dev.id
}

output "lab_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.lab.id
}
