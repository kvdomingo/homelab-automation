include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/github_webhook_allowlist"
}

inputs = {
  base_domain = values.base_domain
  host        = values.host
}
