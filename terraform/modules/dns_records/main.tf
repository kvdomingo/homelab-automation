terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
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

data "github_ip_ranges" "default" {
  count = length(var.github_pages_subdomains) > 0 ? 1 : 0
}

locals {
  # The 192.30.252.0/22 addresses are legacy and absent from GitHub's apex-domain guide.
  github_pages_ips = {
    A    = [for c in try(data.github_ip_ranges.default[0].pages_ipv4, []) : split("/", c)[0] if !startswith(c, "192.30.252.")]
    AAAA = [for c in try(data.github_ip_ranges.default[0].pages_ipv6, []) : split("/", c)[0]]
  }

  github_pages_records = merge([
    for name in var.github_pages_subdomains : merge([
      for type, ips in local.github_pages_ips : {
        for i, ip in sort(ips) : "${name}-${type == "A" ? "ipv4" : "ipv6"}-${i + 1}" => {
          name     = name
          type     = type
          content  = ip
          proxied  = true
          priority = null
          ttl      = 1
        }
      }
    ]...)
  ]...)
}

resource "cloudflare_dns_record" "default" {
  for_each = merge(var.records, local.github_pages_records)

  name     = each.value.name
  type     = each.value.type
  zone_id  = data.cloudflare_zone.default.zone_id
  content  = each.value.content
  proxied  = each.value.proxied
  priority = each.value.priority
  ttl      = each.value.ttl
}
