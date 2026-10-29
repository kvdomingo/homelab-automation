variable "kvdstudio_domain" {
  type = string
}

variable "banyuhai_domain" {
  type = string
}

variable "dev_subdomains" {
  description = "Subdomain of kvdstudio_domain => host:port behind the dev tunnel."
  type        = map(string)
}

variable "lab_subdomains" {
  description = "Subdomains of kvdstudio_domain proxied to <name>.lab.<kvdstudio_domain> through the lab tunnel."
  type        = set(string)
}
