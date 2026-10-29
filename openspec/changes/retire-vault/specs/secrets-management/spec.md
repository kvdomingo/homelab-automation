# Spec Delta

## Purpose

Defines how cluster workloads receive secrets: Infisical is the single source,
and no other secrets store or render-time secret substitution exists.

## ADDED Requirements

### Requirement: Infisical is the only secrets source

Cluster workloads SHALL receive secrets only from Kubernetes secrets that an
`InfisicalSecret` manages. Plaintext secret values SHALL NOT be committed to
git.

#### Scenario: App needs a secret

- **WHEN** an app in `apps/apps/` or `core/apps/` needs a secret
- **THEN** it reads it from an Infisical-managed Kubernetes secret in its
  namespace

#### Scenario: Repo holds no secret values

- **WHEN** `prek run --all-files` runs
- **THEN** `gitleaks` reports no secrets

### Requirement: Vault is not deployed

HashiCorp Vault SHALL NOT run in the cluster.

#### Scenario: App-of-apps has no Vault

- **WHEN** the charts in `apps/apps/` and `core/apps/` are rendered
- **THEN** they contain no Application for Vault

#### Scenario: No Vault namespace

- **WHEN** the cluster's namespaces are listed
- **THEN** there is no `vault` namespace

### Requirement: ArgoCD renders manifests without a secrets plugin

ArgoCD SHALL render every Application with its built-in Helm or directory
source. No Application SHALL use a config management plugin that substitutes
secrets at render time.

#### Scenario: Application source has no plugin

- **WHEN** the charts in `apps/apps/` and `core/apps/` are rendered
- **THEN** no Application source sets `plugin:`

#### Scenario: Repo server has no plugin sidecars

- **WHEN** the ArgoCD repo-server pod is inspected
- **THEN** it has no `argocd-vault-plugin` sidecar or init container

#### Scenario: No substitution placeholders

- **WHEN** the repo is searched for `<path:` placeholders or
  `avp.kubernetes.io` annotations
- **THEN** none are found

### Requirement: Secrets mechanism is documented

`AGENTS.md` SHALL name Infisical as the only secrets mechanism and SHALL NOT
describe `argocd-vault-plugin` as an option.

#### Scenario: Agent reads secrets guidance

- **WHEN** an agent reads the secrets convention in `AGENTS.md`
- **THEN** it is told to use `infisical-secrets/` or an `InfisicalSecret` in
  the chart, with no Vault alternative
