variable "cloudflare_account_name" {
  type = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
  sensitive = true
}

variable "lab_tunnel_secret" {
  type = string
  sensitive = true
}
