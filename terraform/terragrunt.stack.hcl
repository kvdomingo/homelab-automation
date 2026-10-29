locals {
  kvdstudio_domain = "kvd.studio"
  banyuhai_domain  = "banyuh.ai"
  storyofus_domain = "storyof.us.kg"

  dev_kvd_studio_subdomains = {
    jellyfin = "10.10.10.100:8096"
  }

  lab_kvd_studio_subdomains = [
    "argo",
    "atuin",
    "infisical",
    "litellm",
    "lubelogger",
    "nocodb",
    "primerdriver",
    "solidtime",
    "tandoor",
    "umami",
    "unreceiptify",
  ]

  banyuh_ai_subdomains = [
    "@",
    "api",
  ]

  github_pages_ipv4 = {
    1 = "185.199.108.153"
    2 = "185.199.109.153"
    3 = "185.199.110.153"
    4 = "185.199.111.153"
  }
  github_pages_ipv6 = {
    1 = "2606:50c0:8000::153"
    2 = "2606:50c0:8001::153"
    3 = "2606:50c0:8002::153"
    4 = "2606:50c0:8003::153"
  }
}

unit "tunnels" {
  source = "./units/tunnels"
  path   = "tunnels"

  values = {
    kvdstudio_domain = local.kvdstudio_domain
    banyuhai_domain  = local.banyuhai_domain
    dev_subdomains   = local.dev_kvd_studio_subdomains
    lab_subdomains   = local.lab_kvd_studio_subdomains
  }
}

unit "dns-kvd-studio" {
  source = "./units/dns-zone"
  path   = "dns-kvd-studio"

  values = {
    base_domain           = local.kvdstudio_domain
    dev_tunnel_subdomains = keys(local.dev_kvd_studio_subdomains)
    lab_tunnel_subdomains = local.lab_kvd_studio_subdomains
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
        microsoft_domain_verification = {
          type    = "TXT"
          name    = "@"
          content = "MS=B9DD85B6C0438DB6C634911330D9848E1BB2E7EB"
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
          content = "470bf1810574e5e9.vercel-dns-017.com"
          proxied = false
        }
        betterplaridel = {
          type    = "CNAME"
          name    = "betterplaridel"
          content = "b94dec802dbb1537.vercel-dns-017.com"
          proxied = false
        }
        pili_planet_stg = {
          type    = "CNAME"
          name    = "pili-planet-stg"
          content = "2043495636191cbc.vercel-dns-017.com"
          proxied = false
        }
        pili_planet = {
          type    = "CNAME"
          name    = "pili-planet"
          content = "2043495636191cbc.vercel-dns-017.com"
          proxied = false
        }
      },
      {
        for k, v in local.github_pages_ipv4 : "primerdriver-docs-ipv4-${k}" => {
          name    = "primerdriver-docs"
          type    = "A"
          content = v
          proxied = true
        }
      },
      {
        for k, v in local.github_pages_ipv6 : "primerdriver-docs-ipv6-${k}" => {
          name    = "primerdriver-docs"
          type    = "AAAA"
          content = v
          proxied = true
        }
      },
    )
  }
}

unit "dns-banyuh-ai" {
  source = "./units/dns-zone"
  path   = "dns-banyuh-ai"

  values = {
    base_domain           = local.banyuhai_domain
    lab_tunnel_subdomains = local.banyuh_ai_subdomains
  }
}

unit "dns-storyof-us" {
  source = "./units/dns-zone"
  path   = "dns-storyof-us"

  values = {
    base_domain = local.storyofus_domain
    records = {
      _2024_with_daf = {
        type    = "CNAME"
        name    = "2024-with-daf"
        content = "4cee16db81c20404.vercel-dns-017.com"
        proxied = false
      }
      _2025_with_daf = {
        type    = "CNAME"
        name    = "2025-with-daf"
        content = "ead1fc91919dd127.vercel-dns-017.com"
        proxied = false
      }
      _2026_with_daf = {
        type    = "CNAME"
        name    = "2026-with-daf"
        content = "dd9a53cda5c03946.vercel-dns-017.com"
        proxied = false
      }
    }
  }
}
