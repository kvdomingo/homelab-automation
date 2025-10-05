terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~>0.15"
    }
  }

  backend "gcs" {
    prefix = "homelab/tfstate"
    bucket = "my-projects-306716-terraform-backend"
  }
}
