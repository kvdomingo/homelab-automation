resource "cloudflare_tunnel" "dev" {
  account_id = var.cloudflare_account_id
  name       = "homelab-dev"
  secret     = var.dev_tunnel_secret
}
