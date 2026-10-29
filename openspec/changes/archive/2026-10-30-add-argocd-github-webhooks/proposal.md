# Proposal

## Why

ArgoCD finds new commits by polling: `timeout.reconciliation: 120s` plus up to
60s jitter, so a push to `main` takes up to 3 minutes to deploy. The
`primerdriver-previews` ApplicationSet polls the GitHub API every 60s for pull
requests, which delays previews and spends App rate limit. Also,
`argo.kvd.studio/api/webhook` is already public through the Cloudflare tunnel
with no webhook secret set, so ArgoCD accepts any unsigned payload there.

## What Changes

- GitHub sends `push` events from `kvdomingo/homelab-automation` to the
  ArgoCD server webhook (`https://argo.kvd.studio/api/webhook`), so
  Applications refresh within seconds of a push.
- GitHub sends `pull_request` events from `kvdomingo/primerdriver` to the
  ApplicationSet controller at `https://argo.kvd.studio/api/webhook/appset`.
  A Traefik middleware rewrites that path to the controller's fixed
  `/api/webhook`. Previews are created, updated, and deleted within seconds.
- Both webhooks are authenticated twice:
  - At the edge: a Cloudflare WAF rule blocks requests to `/api/webhook` on
    `argo.kvd.studio` unless they come from GitHub's published hook IP ranges.
  - In ArgoCD: payloads are signed with one shared secret from Infisical, and
    ArgoCD rejects payloads without a valid signature.
- The preview generator's `requeueAfterSeconds` goes from 60 to 600. Polling
  stays as a fallback for missed deliveries.
- The GitHub webhooks are created by hand in each repo's settings. Steps are
  recorded in `AGENTS.md`.

## Capabilities

### New Capabilities

- `gitops-webhooks`: how Git events reach ArgoCD — which repos send which
  events to which endpoint, and how deliveries are authenticated.

### Modified Capabilities

None. (`preview-deployments` is not yet in `openspec/specs/`; its in-flight
change owns that spec. The new requeue interval is recorded in this change's
design.)

## Impact

- `argocd/values.yaml`: webhook secret reference, ApplicationSet webhook
  ingress, Traefik `Middleware` in `extraObjects`. Needs `helmfile apply` in
  `argocd/`.
- `infisical-secrets/argocd/secret.yaml`: new managed secret for the webhook
  secret. New Infisical key `GITHUB_WEBHOOK_SECRET` in project `argocd`, env
  `prod`.
- `terraform/terragrunt.stack.hcl`: a new `webhook-allowlist` unit with its
  module in `terraform/modules/github_webhook_allowlist/` (Cloudflare custom WAF
  rule on `kvd.studio`, adds the `hashicorp/http` provider). Needs
  `task tf-plan` and `task tf-apply`.
- `apps-dev/apps/templates/primerdriver-previews.yaml`: `requeueAfterSeconds`.
- GitHub settings of `homelab-automation` and `primerdriver`: one webhook each.
- `AGENTS.md`: webhook setup notes.
