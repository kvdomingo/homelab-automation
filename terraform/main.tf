locals {
  subdomains_to_expose = toset([
    "git",
  ])
}

resource "cloudflare_tunnel" "lab" {
  account_id = var.cloudflare_account_id
  name       = "homelab-lab"
  secret     = var.lab_tunnel_secret
}

resource "cloudflare_tunnel_route" "lab" {
  account_id = var.cloudflare_account_id
  network    = "10.20.0.0/16"
  tunnel_id  = cloudflare_tunnel.lab.id
}

resource "cloudflare_tunnel_config" "lab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.lab.id

  config {
    warp_routing {
      enabled = true
    }

    dynamic "ingress_rule" {
      for_each = local.subdomains_to_expose

      content {
        hostname = "${ingress_rule.value}.lab.kvd.studio"
        service  = "https://${ingress_rule.value}.lab.kvd.studio"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}
