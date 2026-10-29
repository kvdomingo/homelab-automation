# Proposal

## Why

`terraform/` (Cloudflare tunnels and DNS) is driven by the HashiCorp Terraform
CLI, which is BSL-licensed and not pinned anywhere in the repo: whatever
`terraform` happens to be on the workstation is what runs. Moving to OpenTofu
(MPL, drop-in compatible) under Terragrunt gives a pinned, open-source toolchain
and lets the backend and provider config be generated instead of hand-kept.

The Cloudflare provider is on v4, which is deprecated: every plan warns that
`cloudflare_tunnel*` is removed in the next major. Renovate holds Cloudflare
majors back, so the v5 bump has to be done by hand.

## What Changes

- Run the Cloudflare config as a Terragrunt stack, with OpenTofu as the
  underlying binary. The Terraform CLI is no longer used. **BREAKING** for the
  local workflow: `terraform` commands are replaced by `terragrunt stack run`.
- `terraform/terragrunt.stack.hcl` declares four units: `tunnels`,
  `dns-kvd-studio`, `dns-banyuh-ai`, `dns-storyof-us`. The DNS units read
  tunnel IDs from `tunnels` through a dependency. The tunnel subdomain lists
  are defined once in the stack and feed both the tunnel ingress rules and the
  DNS records.
- `terraform/root.hcl` generates the GCS backend (same bucket, one prefix per
  unit under `homelab/`) and the Infisical/Cloudflare provider config.
- The single state at `homelab/tfstate` is split into the four unit states
  with `tofu state mv`. No resource is created, replaced, or destroyed. The old
  object stays in place until the split is verified by a clean apply.
- Provider lock files are regenerated for the OpenTofu registry.
- Upgrade `cloudflare/cloudflare` from 4.52 to the latest 5.x. Tunnels move to
  `cloudflare_zero_trust_tunnel_cloudflared`, `…_route` and `…_config`, DNS
  records to `cloudflare_dns_record`, and the zone lookup to v5's `filter`
  form. State follows through `moved` blocks where v5 supports them, or
  `removed` + `import` blocks where it doesn't. No Cloudflare resource is
  created, replaced, or destroyed.
- Pin `opentofu` and `terragrunt` in `mise.toml`.
- Rewrite the `tf-init` / `tf-plan` / `tf-apply` tasks in `Taskfile.yml` to run
  the stack (still wrapped in `infisical run --`).
- Update `AGENTS.md` (including where to add a subdomain) and `.gitignore`
  (`.terragrunt-cache/`, `.terragrunt-stack/`).

## Capabilities

### New Capabilities

- `cloudflare-provisioning`: How the Cloudflare tunnels and DNS records are
  declared, planned, and applied — the toolchain, the stack layout, where state
  lives, where credentials come from, and that changes are reviewed as a plan
  first.

### Modified Capabilities

None. Renovate keeps tracking the Cloudflare and Infisical providers through
the same `terraform-provider` datasource; `dependency-updates` behavior does
not change.

## Impact

- Code: `terraform/` restructured into `root.hcl`, `terragrunt.stack.hcl`,
  `units/`, and `modules/`; `Taskfile.yml`, `mise.toml`, `AGENTS.md`,
  `.gitignore`.
- State: moves from `homelab/tfstate` to four per-unit prefixes. OpenTofu
  writes a newer state format, so going back to Terraform needs the
  pre-migration backup (bucket object versioning is off).
- No change to live Cloudflare resources: the first stack plan after the state
  split must show no changes in any unit, and the first v5 plan must show only
  moves or imports.
- Lock files move to cloudflare 5.x. Renovate's major-disable rule for
  Cloudflare stays and now holds v6.
- Adding a tunnelled subdomain now means editing
  `terraform/terragrunt.stack.hcl`, not `terraform/main.tf`.
- No CI impact: nothing in `.github/workflows/` runs Terraform.
