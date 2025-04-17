output "dev_tunnel_id" {
  value = cloudflare_tunnel.dev.id
}

output "lab_tunnel_id" {
  value = cloudflare_tunnel.lab.id
}
