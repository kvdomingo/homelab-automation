terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.20"
    }
  }
}

data "cloudflare_zone" "default" {
  filter = {
    name = var.base_domain
  }
}

resource "cloudflare_dns_record" "default" {
  for_each = var.records

  name     = each.value.name
  type     = each.value.type
  zone_id  = data.cloudflare_zone.default.zone_id
  content  = each.value.content
  proxied  = each.value.proxied
  priority = each.value.priority
  ttl      = each.value.ttl
}
