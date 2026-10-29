# data.infisical_secrets.dev is declared in the providers.tf that root.hcl generates.

resource "cloudflare_zero_trust_tunnel_cloudflared" "dev" {
  account_id    = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  name          = "homelab-dev"
  tunnel_secret = data.infisical_secrets.dev.secrets["DEV_TUNNEL_SECRET"].value
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "lab" {
  account_id    = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  name          = "homelab-lab"
  tunnel_secret = data.infisical_secrets.dev.secrets["LAB_TUNNEL_SECRET"].value
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "dev" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  network    = "10.10.0.0/16"
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.dev.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "lab" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  network    = "10.20.0.0/16"
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lab.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "dev" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.dev.id

  config = {
    origin_request = {}
    ingress = concat(
      [
        for name, target in var.dev_subdomains : {
          hostname = "${name}.${var.kvdstudio_domain}"
          service  = "http://${target}"
        }
      ],
      [{ service = "http_status:404" }],
    )
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "lab" {
  account_id = data.infisical_secrets.dev.secrets["CLOUDFLARE_ACCOUNT_ID"].value
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lab.id

  config = {
    origin_request = {}
    ingress = concat(
      [
        {
          hostname = var.banyuhai_domain
          service  = "http://banyuhay-app.banyuhay.svc.cluster.local:3000"
        },
        {
          hostname = "api.${var.banyuhai_domain}"
          service  = "http://banyuhay-api.banyuhay.svc.cluster.local:8000"
        },
      ],
      [
        for name in var.lab_subdomains : {
          hostname = "${name}.${var.kvdstudio_domain}"
          service  = "https://${name}.lab.${var.kvdstudio_domain}"
        }
      ],
      [{ service = "http_status:404" }],
    )
  }
}

moved {
  from = cloudflare_tunnel.dev
  to   = cloudflare_zero_trust_tunnel_cloudflared.dev
}

moved {
  from = cloudflare_tunnel.lab
  to   = cloudflare_zero_trust_tunnel_cloudflared.lab
}

moved {
  from = cloudflare_tunnel_route.dev
  to   = cloudflare_zero_trust_tunnel_cloudflared_route.dev
}

moved {
  from = cloudflare_tunnel_route.lab
  to   = cloudflare_zero_trust_tunnel_cloudflared_route.lab
}

moved {
  from = cloudflare_tunnel_config.dev
  to   = cloudflare_zero_trust_tunnel_cloudflared_config.dev
}

moved {
  from = cloudflare_tunnel_config.lab
  to   = cloudflare_zero_trust_tunnel_cloudflared_config.lab
}
