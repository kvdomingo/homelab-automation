locals {
  base_domain = "kvd.studio"
  subdomains_to_expose = tomap({
    git = "git.lab.kvd.studio"
  })
}

data "cloudflare_zone" "kvd_studio" {
  name = local.base_domain
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
        hostname = "${ingress_rule.key}.${local.base_domain}"
        service  = "https://${ingress_rule.value}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "lab" {
  for_each = local.subdomains_to_expose

  name    = each.key
  type    = "CNAME"
  zone_id = data.cloudflare_zone.kvd_studio.id
  content = "${cloudflare_tunnel.lab.id}.cfargotunnel.com"
  proxied = true
}
