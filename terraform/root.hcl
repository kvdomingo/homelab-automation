terraform_binary = "tofu"

remote_state {
  backend = "gcs"
  config = {
    bucket               = "my-projects-306716-terraform-backend"
    prefix               = "homelab/${basename(path_relative_to_include())}"
    skip_bucket_creation = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOT
variable "infisical_client_id" {
  type      = string
  sensitive = true
}

variable "infisical_client_secret" {
  type      = string
  sensitive = true
}

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
EOT
}
