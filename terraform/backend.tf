terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~>4.0"
    }
  }

  backend "gcs" {
    prefix = "homelab/tfstate"
    bucket = "my-projects-306716-terraform-backend"
  }
}
