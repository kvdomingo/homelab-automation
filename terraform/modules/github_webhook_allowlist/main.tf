data "cloudflare_zone" "default" {
  filter = {
    name = var.base_domain
  }
}

data "http" "github_meta" {
  url = "https://api.github.com/meta"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

locals {
  github_hook_cidrs = jsondecode(data.http.github_meta.response_body).hooks
}

# A zone has one entry-point ruleset per phase, so dashboard-made custom rules must be kept here too.
import {
  to = cloudflare_ruleset.firewall_custom
  id = "zones/${data.cloudflare_zone.default.zone_id}/ee151954227244099046067be3f3b4fb"
}

resource "cloudflare_ruleset" "firewall_custom" {
  zone_id = data.cloudflare_zone.default.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [
    # Created by Cloudflare AI Crawl Control; the ref ties it back to that dashboard.
    {
      ref         = "[CF AI Audit]"
      description = "AI Crawl Control - Block AI bots by User Agent"
      action      = "block"
      expression  = "(http.request.uri.path ne \"/robots.txt\") and ((http.user_agent contains \"ChatGPT-User\"))"
      enabled     = true
    },
    {
      description = "Only GitHub hook IPs may reach ArgoCD webhooks"
      action      = "block"
      expression  = "(http.host eq \"${var.host}\" and starts_with(http.request.uri.path, \"/api/webhook\") and not ip.src in {${join(" ", local.github_hook_cidrs)}})"
      enabled     = true
    },
  ]
}
