terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.0"
    }
  }
}

data "cloudflare_zone" "default" {
  name = var.base_domain
}

resource "cloudflare_record" "default" {
  for_each = var.records

  name     = each.value.name
  type     = each.value.type
  zone_id  = data.cloudflare_zone.default.id
  content  = each.value.content
  proxied  = each.value.proxied
  priority = each.value.priority
}
