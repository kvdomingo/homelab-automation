include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/tunnels"
}

inputs = {
  kvdstudio_domain = values.kvdstudio_domain
  banyuhai_domain  = values.banyuhai_domain
  dev_subdomains   = values.dev_subdomains
  lab_subdomains   = values.lab_subdomains
}
