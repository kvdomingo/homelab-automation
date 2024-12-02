variable "base_domain" {
  type = string
}

variable "records" {
  type = map(object({
    type    = string
    name    = string
    content = string
    proxied = bool
    priority = optional(number)
  }))
  default = {
    priority = null
  }
}
