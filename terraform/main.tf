locals {
  base_domain = "kvd.studio"
  subdomains_to_expose = tomap({
    banyuhay     = "banyuhay.lab.kvd.studio"
    git          = "git.lab.kvd.studio"
    primerdriver = "primerdriver.lab.kvd.studio"
    umami        = "umami.lab.kvd.studio"
  })
  github_pages_ipv4 = tomap({
    1 = "185.199.108.153"
    2 = "185.199.109.153"
    3 = "185.199.110.153"
    4 = "185.199.111.153"
  })
  github_pages_ipv6 = tomap({
    1 = "2606:50c0:8000::153"
    2 = "2606:50c0:8001::153"
    3 = "2606:50c0:8002::153"
    4 = "2606:50c0:8003::153"
  })

  records = tomap({
    douglas_crawler_api = {
      type    = "CNAME"
      name    = "douglas-cr-api"
      content = "ghs.googlehosted.com."
      proxied = true
    }
    gcp_domain_verification = {
      type    = "TXT"
      name    = "@"
      content = "google-site-verification=tIAe-0kYQ5fk42kI2nw2HGh50tUB-SDRf44JyxvSaFc"
      proxied = false
    }
    hannibot = {
      type    = "CNAME"
      name    = "hannibot"
      content = "cname.vercel-dns.com."
      proxied = true
    }
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

resource "cloudflare_record" "primerdriver-docs-ipv4" {
  for_each = local.github_pages_ipv4

  name    = "primerdriver-docs"
  type    = "A"
  zone_id = data.cloudflare_zone.kvd_studio.id
  content = each.value
  proxied = true
}

resource "cloudflare_record" "primerdriver-docs-ipv6" {
  for_each = local.github_pages_ipv6

  name    = "primerdriver-docs"
  type    = "AAAA"
  zone_id = data.cloudflare_zone.kvd_studio.id
  content = each.value
  proxied = true
}

resource "cloudflare_record" "kvdstudio" {
  for_each = local.records

  name    = each.value.name
  type    = each.value.type
  zone_id = data.cloudflare_zone.kvd_studio.id
  content = each.value.content
  proxied = each.value.proxied
}
