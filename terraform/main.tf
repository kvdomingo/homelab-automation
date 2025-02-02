locals {
  kvdstudio_domain = "kvd.studio"
  banyuhai_domain  = "banyuh.ai"

  lab_kvd_studio_subdomains = toset([
    "git",
    "primerdriver",
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

    ingress_rule {
      hostname = "banyuh.ai"
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
  base_domain = "kvd.studio"
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
      hannibot = {
        type    = "CNAME"
        name    = "hannibot"
        content = "cname.vercel-dns.com."
        proxied = true
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
  base_domain = "banyuh.ai"
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

module "story_of_us" {
  source      = "./modules/dns_records"
  base_domain = "storyof.us.kg"
  records = {
    _2024_with_daf = {
      type    = "CNAME"
      name    = "2024-with-daf"
      content = "cname.vercel-dns.com."
      proxied = true
    }
    _2025_with_daf = {
      type    = "CNAME"
      name    = "2025-with-daf"
      content = "cname.vercel-dns.com."
      proxied = true
    }
    zoho_verification = {
      type    = "TXT"
      name    = "@"
      content = "zoho-verification=zb47166322.zmverify.zoho.com"
      proxied = false
    }
    mx1 = {
      type     = "MX"
      name     = "@"
      content  = "mx.zoho.com"
      proxied  = false
      priority = 10
    }
    mx2 = {
      type     = "MX"
      name     = "@"
      content  = "mx2.zoho.com"
      proxied  = false
      priority = 20
    }
    mx3 = {
      type     = "MX"
      name     = "@"
      content  = "mx3.zoho.com"
      proxied  = false
      priority = 50
    }
    spf = {
      type    = "TXT"
      name    = "@"
      content = "v=spf1 include:zohomail.com ~all"
      proxied = false
    }
    dkim = {
      type    = "TXT"
      name    = "zmail._domainkey"
      content = "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCbza42GR2A7+vZQL3tHVhmdKK/ZNyGOOEJ8BAq7T7g7nGOnBjQb6tMnHt2o9d5Ut4bEE7LGYny1hIH1uhKj5v+57vp9kT8EVlE1ghVTd6UhKBGDp2Ljp28vj8ZCO5GFwanMrQ4p4vWHTuTPEVLQqTyHon6x1iWMjOgzsCb2t9g0QIDAQAB"
      proxied = false
    }
  }
}
