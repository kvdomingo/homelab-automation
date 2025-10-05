provider "infisical" {
  host = "https://infisical.lab.kvd.studio"
  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

data "infisical_projects" "default" {
  slug = "homelab-terraform"
}

data "infisical_secrets" "dev" {
  env_slug     = "dev"
  workspace_id = data.infisical_projects.default.id
  folder_path  = "/"
}

provider "cloudflare" {
  api_token = data.infisical_secrets.dev.secrets["CLOUDFLARE_API_TOKEN"].value
}
