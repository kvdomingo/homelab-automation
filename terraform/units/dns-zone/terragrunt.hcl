include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/dns_records"
}

dependency "tunnels" {
  config_path = "../tunnels"

  mock_outputs = {
    dev_tunnel_id = "00000000-0000-0000-0000-000000000000"
    lab_tunnel_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = {
  base_domain = values.base_domain
  records = merge(
    try(values.records, {}),
    {
      for name in try(values.dev_tunnel_subdomains, []) : "cftunnel-dev-${name}" => {
        name    = name
        type    = "CNAME"
        content = "${dependency.tunnels.outputs.dev_tunnel_id}.cfargotunnel.com"
        proxied = true
      }
    },
    {
      for name in try(values.lab_tunnel_subdomains, []) : "cftunnel-${name}" => {
        name    = name
        type    = "CNAME"
        content = "${dependency.tunnels.outputs.lab_tunnel_id}.cfargotunnel.com"
        proxied = true
      }
    },
  )
}
