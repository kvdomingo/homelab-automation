variable "base_domain" {
  type = string
}

variable "host" {
  description = "Hostname whose /api/webhook* paths accept only GitHub hook IPs."
  type        = string
}
