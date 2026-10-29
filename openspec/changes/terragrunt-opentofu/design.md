# Design

## Context

`terraform/` was a single root module: `backend.tf` (required providers + GCS
backend), `providers.tf` (Infisical provider, which then supplies the Cloudflare
API token), `main.tf` (tunnels, tunnel routes, tunnel configs, and three
`modules/dns_records` instances), `variables.tf` (Infisical client ID/secret),
`output.tf`. Locked providers: `cloudflare/cloudflare` 4.52.10 and
`infisical/infisical` 0.20.7. There is one environment and one state object (14
resources). Operators run it by hand through `task tf-init|tf-plan|tf-apply`;
`tf-plan`/`tf-apply` wrap the CLI in `infisical run --`, which supplies the
`infisical_client_*` variables. No CI runs it. Renovate tracks the providers via
the `terraform-provider` datasource and disables Cloudflare majors. The state
bucket has object versioning off.

A first single-unit implementation (one `terraform/terragrunt.hcl`) planned
clean against the existing state. Two things it surfaced shape this design:
Terragrunt 1.2 always runs from a copy under `.terragrunt-cache/`, and with no
OpenTofu-registry lock entries, `>= 4` resolved cloudflare to v5.

## Goals / Non-Goals

**Goals:**

- Swap the toolchain to Terragrunt + OpenTofu with zero resource diff.
- Upgrade the Cloudflare provider to v5 without creating, replacing, or
  destroying any resource.
- Lay the config out as a Terragrunt stack: tunnels plus one DNS unit per zone.
- Keep the same bucket, credentials flow, and task names.

**Non-Goals:**

- Multiple environments.
- Separate catalog or module repos: units and modules live in this repo and are
  referenced by local path.
- Running plan/apply from CI.
- Pinning the other `latest` tools in `mise.toml`.

## Decisions

### Stack with four units, local catalog

`terraform/terragrunt.stack.hcl` has `unit` blocks pointing at `units/tunnels`
and `units/dns-zone`; `dns-zone` is used three times (`dns-kvd-studio`,
`dns-banyuh-ai`, `dns-storyof-us`) with different `values`. Units source
`modules/tunnels` (today's tunnel resources and outputs) and the existing
`modules/dns_records`.

Stack `locals` hold the domains and subdomain lists, so each list is defined
once. `tunnels` receives the lists for its ingress rules. `dns-zone` takes
static `records` plus `tunnel_subdomains` and builds the tunnel CNAMEs in
`inputs` from `dependency.tunnels.outputs`, with mock outputs for
init/validate only, so a DNS plan always uses the real tunnel IDs. The stack
orders apply tunnels-first. `terraform/.terragrunt-filters` (`!./units/**`)
keeps `stack run` from treating the catalog templates in `units/` as units.

Keep the directory name `terraform/`; the name describes the language, which
OpenTofu reads unchanged.

Alternatives: the three-repo catalog/live/modules pattern — one operator and
one environment, so the extra repos are pure overhead; rejected. A single unit
wrapping the old root module — stack-shaped but no blast-radius split;
rejected.

### `root.hcl` generates backend and providers

`root.hcl` declares a GCS `remote_state` with a per-unit prefix under
`homelab/` (derived from the unit path), `skip_bucket_creation = true` (the
bucket exists and is not owned by this repo), and a generated `backend.tf`. It
also generates `providers.tf`: the Infisical provider, the Infisical project and
secrets data sources, the Cloudflare provider, and the `infisical_client_*`
variables. Every unit includes it.

`required_providers` stays in each module's `versions.tf` so Renovate's
terraform manager keeps detecting the providers with no config change. Each
module carries its own `.terraform.lock.hcl`.

### Upgrade to Cloudflare v5 after the state split

The upgrade runs per unit on top of the split state, on the same branch,
before the first apply. Renames:

- `cloudflare_tunnel` → `cloudflare_zero_trust_tunnel_cloudflared`
  (`secret` → `tunnel_secret`)
- `cloudflare_tunnel_route` → `cloudflare_zero_trust_tunnel_cloudflared_route`
- `cloudflare_tunnel_config` → `cloudflare_zero_trust_tunnel_cloudflared_config`
  (nested `config {}` blocks become a `config = { ingress = [...],
  warp_routing = {...} }` object)
- `cloudflare_record` → `cloudflare_dns_record` (`ttl` is required; default
  `1`, automatic)
- `data "cloudflare_zone"` → `filter = { name = … }`

State moves with `moved` blocks where the pinned 5.x release supports moving
from the v4 type. Otherwise use `removed { lifecycle { destroy = false } }`
plus `import` blocks, with IDs taken from the split states. The migration
blocks are removed after the first clean apply.

### OpenTofu selected explicitly

Set `terraform_binary = "tofu"` in `root.hcl` so behavior does not depend on
which binaries are on `PATH` or on Terragrunt's default-binary heuristics.

### Pin both tools in `mise.toml`

Add `opentofu` and `terragrunt` at concrete versions (latest stable at
implementation time). Renovate's mise manager can bump them like other pins.

### Task names unchanged

`tf-init`, `tf-plan`, `tf-apply` keep their names and saved-plan flow, now
running the stack from `terraform/`: plan saves per-unit plans with
`--out-dir .tfplan`, and apply reads them back with the same flag.
`infisical run --` stays on plan and apply only; init touches just the backend,
using ambient GCP credentials.

## Risks / Trade-offs

- [State split misses or duplicates a resource] → Split offline: pull the
  state, then `tofu state mv -state=… -state-out=…` into four local files.
  Addresses change, e.g. `module.kvdstudio.cloudflare_record.default[...]`
  becomes `cloudflare_record.default[...]` in `dns-kvd-studio`; tunnel
  addresses stay the same. Check the per-unit managed instances sum to 39
  (the 5 data sources stay behind and are read again in each unit) and no
  address appears twice. `state mv` doesn't move root outputs, so copy
  `dev_tunnel_id`/`lab_tunnel_id` from the backup into the `tunnels` state, or
  the DNS units can't resolve the dependency. GCS init creates an empty
  `default.tfstate` at each new prefix, so push each file with `-force`. Leave
  `homelab/tfstate` untouched. Rollback before any apply: delete the new
  prefixes and revert the commit.
- [Lock files under the generated `.terragrunt-stack/` are git-ignored, so
  provider versions could float — `>= 4` pulls cloudflare v5] → Commit lock
  files in the module dirs and verify init selects 4.52.10 in every unit. If
  Terragrunt ignores them, tighten the module constraint to `~> 4.52`.
- [DNS units depend on tunnel outputs] → Mock outputs for plan/validate;
  real outputs come from the `tunnels` state, which already holds both tunnels
  after the split.
- [State provider addresses are `registry.terraform.io/...`; OpenTofu resolves
  `cloudflare/cloudflare` to `registry.opentofu.org`] → The single-unit plan
  was clean, so OpenTofu treats them as equivalent. If a unit reports a
  provider mismatch, run `tofu state replace-provider` there, then re-plan.
- [State was last written by Terraform 1.17, which OpenTofu's migration guide
  doesn't cover] → The single-unit plan read it with no changes. If a split
  state is rejected, stop and don't apply.
- [OpenTofu rewrites state on first apply; Terraform cannot read it back;
  bucket versioning is off] → The pre-migration `state pull` backup outside the
  repo is the only rollback. Rollback = restore `homelab/tfstate` from it,
  delete the unit prefixes, and revert the commit.
- [Renovate may not update lock files whose hashes come from
  `registry.opentofu.org`] → Check the Dependency Dashboard after merge; if
  providers show as errored, add a package rule with `registryUrls` for the
  OpenTofu registry.
- [Lock files regenerated on one platform only] → Run `providers lock` for
  `linux_amd64`, `linux_arm64`, and `darwin_arm64` so other machines don't
  rewrite them.
- [Importing into v5 surfaces in-place diffs] → Review each one. Accept only
  no-op normalizations (e.g. computed defaults); stop on anything that changes
  live behavior.
- [Tunnel replacement: v5 treats `tunnel_secret` as force-new, and a replaced
  tunnel breaks cloudflared] → Feed it the same Infisical secret and check the
  plan never replaces a tunnel.

## Migration Plan

1. Back up state (`state pull > backup.tfstate`, outside the repo).
2. Land everything on one branch: stack config, `mise.toml` pins, Taskfile,
   AGENTS.md, `.gitignore`, and this change's artifacts.
3. Split the state into the four unit prefixes; leave `homelab/tfstate` alone.
4. `task tf-init`, then `task tf-plan`; every unit must report no changes. Do
   not apply until they do.
5. Upgrade the units to Cloudflare v5; the plan must show only moves and
   imports.
6. Merge. The first real apply writes OpenTofu state and carries out the moves
   and imports.
7. After a clean apply, delete `homelab/tfstate`, remove the migration blocks,
   and re-plan to no changes.

Rollback before any OpenTofu apply: delete the unit prefixes and revert the
commit; `homelab/tfstate` is untouched. Rollback after: restore from the
backup, delete the unit prefixes, then revert.
