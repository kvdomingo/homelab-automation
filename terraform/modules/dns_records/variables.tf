variable "base_domain" {
  type = string
}

variable "records" {
  type = map(object({
    type     = string
    name     = string
    content  = string
    proxied  = bool
    priority = optional(number)
    ttl      = optional(number, 1)
  }))
  default = {
    priority = null
  }
}

variable "github_pages_subdomains" {
  type    = list(string)
  default = []
}
