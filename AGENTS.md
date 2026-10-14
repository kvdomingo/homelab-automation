# AGENTS.md

GitOps repo for a k3s homelab. Remote:
`github.com/kvdomingo/homelab-automation`.

## Deploying

Never apply changes by hand (`kubectl apply`, `helm upgrade`, `scp`). Push to
`main` and let automation deploy:

- **Kubernetes apps**: ArgoCD auto-syncs from `main` (`selfHeal` + `prune`).
- **`bind9/`**: `.github/workflows/deploy-bind.yaml` runs `docker compose` on a
  self-hosted runner.
- **`tailscale/acl.hujson`**: `.github/workflows/tailscale.yaml` tests, then
  applies the ACL.
- **`terraform/`** (Cloudflare DNS, GCS backend): manual, `task tf-plan` then
  `task tf-apply` (wrapped in `infisical run`).

## Layout

- `apps/apps/` and `core/apps/`: app-of-apps Helm charts. One ArgoCD
  `Application` per file in `templates/`, each wrapped in
  `{{- if not .Values.disable<Name> }}`. `apps/application.yaml` and
  `core/application.yaml` are the roots (applied once at bootstrap).
- `<app>/`: one directory per in-house Helm chart (`Chart.yaml`, `values.yaml`,
  `templates/`), referenced by `path:` from an `Application`.
- Vendor charts are referenced directly in the `Application` (`sources:` with an
  OCI/Helm repo plus inline `valuesObject`). See
  `apps/apps/templates/litellm.yaml`.
- `infisical-secrets/<app>/`: `InfisicalSecret` CRs that materialize
  `<app>-secrets` in the app namespace. Added as an extra `sources:` entry.
- `argocd/`, `infisical/`, `promstack/`, `core-services/`: bootstrap components
  installed with `helmfile apply`.
- `ansible/`: node provisioning. Inventory is in `ansible/inventory/hosts.ini`.
  Run playbooks from `ansible/`, e.g. `ansible-playbook setup-k8s-servers.yml`.
  The ansible tasks in `Taskfile.yml` point at old paths.

## Conventions

- Ingress: `<app>.lab.kvd.studio` (internal). Add `<app>.kvd.studio` only if the
  app is exposed externally. Ingress class is `traefik`. Add `gethomepage.dev/*`
  annotations so the app shows up on the Homepage dashboard.
- Images use `tag: latest` and are updated by Keel (`keel.sh/policy: force`,
  `match-tag`, `trigger: poll`).
- Cluster mixes amd64 and arm64 (Pi 5 agents). Images that are amd64-only need
  node affinity `kubernetes.io/arch NotIn [arm64, arm]`.
- Bitnami images come from `bitnamilegacy/*`.
- Secrets: new apps use Infisical (`infisical-secrets/`). Older apps use
  `argocd-vault-plugin-helm`. Never commit plaintext secrets. `gitleaks` runs in
  pre-commit.
- Workloads that consume an `InfisicalSecret` get the deployment annotation
  `secrets.infisical.com/auto-reload: "true"` so they redeploy when the secret
  changes.
- Commits: `type(scope): summary`, where scope is the app name (e.g.
  `feat(litellm): add chart`).

## Adding an app

1. Create the chart in `<app>/`, or use a vendor chart.
2. If the app needs secrets, add `infisical-secrets/<app>/secret.yaml`.
3. Add `apps/apps/templates/<app>.yaml`, modeled on an existing app.
4. To give the app a Cloudflare DNS record, add it to the subdomain sets in
   `terraform/main.tf`.

## Running locally

Prefix commands that need env vars with `infisical run -- `, e.g.
`infisical run -- terraform plan`.

## Checks

- `pre-commit run --all-files`
- `helm template <app>` for a local chart
