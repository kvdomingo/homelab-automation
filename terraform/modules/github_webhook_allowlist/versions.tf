terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.20"
    }
  }
}
