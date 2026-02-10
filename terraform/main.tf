locals {
  kvdstudio_domain = "kvd.studio"
  banyuhai_domain  = "banyuh.ai"
  storyofus_domain = "storyof.us.kg"

  dev_kvd_studio_subdomains = tomap({
    jellyfin = "10.10.10.100:8096"
  })

  lab_kvd_studio_subdomains = toset([
    "git",
    "infisical",
    "nocodb",
    "primerdriver",
    "tandoor",
    "umami",
    "unreceiptify",
  ])

  banyuh_ai_subdomains = toset([
    "@",
  ])

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
}

resource "cloudflare_tunnel" "dev" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  name       = "homelab-dev"
  secret     = data.infisical_secrets.dev.secrets["DEV_TUNNEL_SECRET"].value
}

resource "cloudflare_tunnel" "lab" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  name       = "homelab-lab"
  secret     = data.infisical_secrets.dev.secrets["LAB_TUNNEL_SECRET"].value
}

resource "cloudflare_tunnel_route" "dev" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  network    = "10.10.0.0/16"
  tunnel_id  = cloudflare_tunnel.dev.id
}

resource "cloudflare_tunnel_route" "lab" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  network    = "10.20.0.0/16"
  tunnel_id  = cloudflare_tunnel.lab.id
}

resource "cloudflare_tunnel_config" "dev" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  tunnel_id  = cloudflare_tunnel.dev.id

  config {
    warp_routing {
      enabled = true
    }

    dynamic "ingress_rule" {
      for_each = local.dev_kvd_studio_subdomains

      content {
        hostname = "${ingress_rule.key}.${local.kvdstudio_domain}"
        service  = "http://${ingress_rule.value}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_tunnel_config" "lab" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  tunnel_id  = cloudflare_tunnel.lab.id

  config {
    warp_routing {
      enabled = true
    }

    ingress_rule {
      hostname = local.banyuhai_domain
      service  = "http://banyuhay.banyuhay.svc.cluster.local:8000"
    }

    dynamic "ingress_rule" {
      for_each = local.lab_kvd_studio_subdomains

      content {
        hostname = "${ingress_rule.value}.${local.kvdstudio_domain}"
        service  = "https://${ingress_rule.value}.lab.${local.kvdstudio_domain}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

module "kvdstudio" {
  source      = "./modules/dns_records"
  base_domain = local.kvdstudio_domain
  records = merge(
    {
      bluesky_verification = {
        type    = "TXT"
        name    = "_atproto"
        content = "did=did:plc:f3p5jcwsxjdhgippakojyyak"
        proxied = false
      }
      gcp_domain_verification = {
        type    = "TXT"
        name    = "@"
        content = "google-site-verification=tIAe-0kYQ5fk42kI2nw2HGh50tUB-SDRf44JyxvSaFc"
        proxied = false
      }
      openai_verification = {
        type    = "TXT"
        name    = "@"
        content = "openai-domain-verification=dv-1rHkOFyDBYYVTS3rj8qDXpip"
        proxied = false
      }
      hannibot = {
        type    = "CNAME"
        name    = "hannibot"
        content = "470bf1810574e5e9.vercel-dns-017.com."
        proxied = false
      }
      betterplaridel = {
        type    = "CNAME"
        name    = "betterplaridel"
        content = "b94dec802dbb1537.vercel-dns-017.com."
        proxied = false
      }
    },
    {
      for k, v in local.github_pages_ipv4 : "primerdriver-docs-ipv4-${k}" =>
      {
        name    = "primerdriver-docs"
        type    = "A"
        content = v
        proxied = true
      }
    },
    {
      for k, v in local.github_pages_ipv6 : "primerdriver-docs-ipv6-${k}" =>
      {
        name    = "primerdriver-docs"
        type    = "AAAA"
        content = v
        proxied = true
      }
    },
    {
      for k, _ in local.dev_kvd_studio_subdomains : "cftunnel-dev-${k}" =>
      {
        name    = k
        type    = "CNAME"
        content = "${cloudflare_tunnel.dev.id}.cfargotunnel.com"
        proxied = true
      }
    },
    {
      for i, v in local.lab_kvd_studio_subdomains : "cftunnel-${v}" =>
      {
        name    = v
        type    = "CNAME"
        content = "${cloudflare_tunnel.lab.id}.cfargotunnel.com"
        proxied = true
      }
    },
  )
}

module "banyuh_ai" {
  source      = "./modules/dns_records"
  base_domain = local.banyuhai_domain
  records = merge(
    {
      for i, v in local.banyuh_ai_subdomains : "cftunnel-${v}" =>
      {
        name    = v
        type    = "CNAME"
        content = "${cloudflare_tunnel.lab.id}.cfargotunnel.com"
        proxied = true
      }
    },
  )
}

module "storyofus" {
  source      = "./modules/dns_records"
  base_domain = local.storyofus_domain
  records = {
    _2024_with_daf = {
      type    = "CNAME"
      name    = "2024-with-daf"
      content = "4cee16db81c20404.vercel-dns-017.com."
      proxied = false
    }
    _2025_with_daf = {
      type    = "CNAME"
      name    = "2025-with-daf"
      content = "ead1fc91919dd127.vercel-dns-017.com."
      proxied = false
    }
    _2026_with_daf = {
      type    = "CNAME"
      name    = "2026-with-daf"
      content = "dd9a53cda5c03946.vercel-dns-017.com."
      proxied = false
    }
  }
}
