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
