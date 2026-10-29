# data.infisical_secrets.dev is declared in the providers.tf that root.hcl generates.

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
      for_each = var.dev_subdomains

      content {
        hostname = "${ingress_rule.key}.${var.kvdstudio_domain}"
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
      hostname = var.banyuhai_domain
      service  = "http://banyuhay-app.banyuhay.svc.cluster.local:3000"
    }

    ingress_rule {
      hostname = "api.${var.banyuhai_domain}"
      service  = "http://banyuhay-api.banyuhay.svc.cluster.local:8000"
    }

    dynamic "ingress_rule" {
      for_each = var.lab_subdomains

      content {
        hostname = "${ingress_rule.value}.${var.kvdstudio_domain}"
        service  = "https://${ingress_rule.value}.lab.${var.kvdstudio_domain}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}
