# Tasks

## 1. Pre-migration safety

- [x] 1.1 Pull current state (written by Terraform 1.17) to a file outside the
  repo; verify the backup is non-empty, and check the pinned OpenTofu
  release's migration notes for Terraform 1.17 state
- [x] 1.2 Confirm object versioning is on for
      `my-projects-306716-terraform-backend`
      (`gcloud storage buckets describe ... --format='value(versioning_enabled)'`
      prints `True`), or note the local backup as the only rollback

## 2. Toolchain

- [x] 2.1 Add `opentofu` and `terragrunt` at concrete versions to `mise.toml`;
  verify `mise install` succeeds and `tofu version` / `terragrunt --version`
  print the pinned versions

## 3. Stack config

- [x] 3.1 Move the tunnel resources and outputs from `terraform/main.tf` and
  `output.tf` into `terraform/modules/tunnels/` with a `versions.tf`; add
  `infisical` to the `modules/dns_records` required providers; delete the root
  `main.tf`, `output.tf`, `providers.tf`, `variables.tf`, `versions.tf`,
  `terragrunt.hcl`, and `.terraform.lock.hcl`
- [x] 3.2 Add `terraform/root.hcl` (`terraform_binary = "tofu"`, GCS
  `remote_state` with a per-unit prefix under `homelab/` and
  `skip_bucket_creation = true`, generated providers and Infisical variables)
- [x] 3.3 Add `units/tunnels` and `units/dns-zone` (dependency on `tunnels`
  with mock outputs) and `terragrunt.stack.hcl` with the four units and the
  domain and subdomain lists; verify `terragrunt stack generate` succeeds
- [x] 3.4 Generate OpenTofu lock files in each module for `linux_amd64`,
  `linux_arm64`, `darwin_arm64`; verify init selects cloudflare 4.52.10 and
  infisical 0.20.7 in every unit, else tighten the module constraints
- [x] 3.5 Add `.terragrunt-stack/` to `.gitignore` (keep `.terragrunt-cache/`,
  drop `terraform/backend.tf`); verify `git status` shows no generated files
  after a stack run

## 4. State split

- [x] 4.1 Split the pulled state into four unit states with
  `tofu state mv -state=… -state-out=…`; verify the per-unit managed
  instances sum to 39 (data sources stay behind) and no address appears in two
  files
- [x] 4.2 Copy the tunnel outputs into the `tunnels` state, then push each unit
  state to its prefix with `-force` (init leaves an empty state there); leave
  `homelab/tfstate` in place

## 5. Tasks and docs

- [x] 5.1 Rewrite `tf-init`, `tf-plan`, `tf-apply` in `Taskfile.yml` to run the
  stack (keeping `infisical run --` on plan/apply and saving plans with
  `--out-dir .tfplan`);
  verify `task tf-plan` reports no changes in all four units — fix provider
  addresses with `tofu state replace-provider` if a unit reports a mismatch;
  otherwise stop without applying
- [x] 5.2 Verify `task tf-plan` fails before reaching Cloudflare when run
  without `infisical run` credentials
- [x] 5.3 Update `AGENTS.md` (the `terraform/` bullet, and "Adding an app" step
  4 → `terraform/terragrunt.stack.hcl`); verify `prek run --all-files` passes

## 6. Cloudflare v5

- [x] 6.1 Set the module cloudflare constraints to the latest 5.x minor and
  regenerate both module lock files for `linux_amd64`, `linux_arm64`,
  `darwin_arm64`
- [x] 6.2 Rewrite `modules/tunnels` with the v5 tunnel types and add the state
  migration blocks (`moved`, or `removed` + `import`)
- [x] 6.3 Rewrite `modules/dns_records` with `cloudflare_dns_record` (`ttl`
  default 1) and the v5 `cloudflare_zone` filter; add migration blocks
- [x] 6.4 Verify `task tf-plan`: every unit shows only moves or imports, no
  create/replace/destroy, no tunnel replacement, and no deprecation warnings;
  otherwise stop without applying

## 7. Integration

- [ ] 7.1 After merge, check Renovate's Dependency Dashboard lists the
  cloudflare and infisical providers (from `modules/*/versions.tf`) and the
  mise tools without errors; if the providers error on the OpenTofu lock
  files, add a package rule with the OpenTofu `registryUrls`
- [x] 7.2 After a clean apply, delete the old `homelab/tfstate` object
- [x] 7.3 After that apply, remove the migration blocks; verify the plan
  reports no changes
