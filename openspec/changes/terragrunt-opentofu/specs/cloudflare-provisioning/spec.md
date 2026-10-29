# Spec Delta

## Purpose

Declare the homelab's Cloudflare tunnels and DNS records as code, and plan and
apply them with a pinned, open-source toolchain against shared remote state.

## ADDED Requirements

### Requirement: Provisioned with Terragrunt and OpenTofu

Cloudflare resources SHALL be planned and applied through Terragrunt, with
OpenTofu as the underlying binary. The HashiCorp Terraform CLI SHALL NOT be
needed to plan or apply.

#### Scenario: Plan on a workstation without Terraform

- **WHEN** an operator with only the repo's pinned tools installed runs the
  plan task
- **THEN** a stack plan is produced by OpenTofu, and no `terraform` binary is
  invoked

### Requirement: Organized as a Terragrunt stack

The config SHALL be a Terragrunt stack whose units are the tunnels and one DNS
unit per zone. Each tunnelled subdomain list SHALL be defined once and feed
both the tunnel ingress rules and the DNS records.

#### Scenario: Add a tunnelled subdomain

- **WHEN** an operator adds a name to a lab subdomain list in the stack file
- **THEN** the plan shows a new ingress rule in `tunnels` and a new CNAME in
  the matching DNS unit, and nothing else

### Requirement: Toolchain versions are pinned

The OpenTofu and Terragrunt versions SHALL be pinned to concrete versions in
the repo's tool manifest.

#### Scenario: Fresh checkout

- **WHEN** an operator installs the tools declared by the repo
- **THEN** they get the same OpenTofu and Terragrunt versions as every other
  operator, not whatever version is newest

### Requirement: State lives in the existing bucket, one object per unit

State SHALL be stored in the GCS bucket `my-projects-306716-terraform-backend`
under a separate `homelab/<unit>` prefix for each unit, with locking. Local
state files SHALL NOT be used or committed.

#### Scenario: Concurrent apply

- **WHEN** two operators run apply at the same time
- **THEN** one of them is refused by the state lock

#### Scenario: Unit isolation

- **WHEN** one DNS unit is applied
- **THEN** no other unit's state is locked or written

### Requirement: Migration does not change live resources

Switching toolchains and splitting state SHALL NOT create, replace, or destroy
any Cloudflare resource.

#### Scenario: State split

- **WHEN** the single state is split into unit states
- **THEN** every managed resource appears in exactly one unit state

#### Scenario: First plan after migration

- **WHEN** the plan task runs for the first time on the new toolchain against
  the split state, before the provider upgrade
- **THEN** it reports no changes in any unit

#### Scenario: Provider upgrade

- **WHEN** the v5 config is first planned against the v4 state
- **THEN** the plan contains only moves or imports, with no create, replace,
  or destroy

### Requirement: Cloudflare provider v5

Cloudflare resources SHALL be declared with the v5 resource types of
`cloudflare/cloudflare` 5.x.

#### Scenario: No deprecated resource types

- **WHEN** the plan task runs
- **THEN** it reports no v4 resource-type deprecation warnings

### Requirement: Credentials come from Infisical

Provider credentials SHALL be read from Infisical at run time. No credential
SHALL be committed to the repo.

#### Scenario: Plan without Infisical session

- **WHEN** the plan task runs without Infisical credentials available
- **THEN** it fails before contacting Cloudflare, and no secret is read from a
  file in the repo

### Requirement: Apply only a reviewed plan

Changes SHALL be applied from saved plan files produced by the plan task, so
what is applied is exactly what was reviewed.

#### Scenario: Apply after plan

- **WHEN** an operator runs the apply task after the plan task
- **THEN** exactly the saved plans are applied, with no new diff computed
