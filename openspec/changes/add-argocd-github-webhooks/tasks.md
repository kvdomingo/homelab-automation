# Tasks

## 1. Webhook secret

- [x] 1.1 (Manual, Infisical) Add `GITHUB_WEBHOOK_SECRET` (e.g.
      `openssl rand -hex 32`) to project `argocd`, env `prod`. Verify the key
      shows in the Infisical UI.
- [x] 1.2 In `infisical-secrets/argocd/secret.yaml`, add a
      `managedKubeSecretReferences` entry producing `argocd-webhook-secret` in
      `argocd`, key `webhook.github.secret` from `GITHUB_WEBHOOK_SECRET`,
      label `app.kubernetes.io/part-of: argocd`. Verify
      `prek run --all-files` passes.
- [x] 1.3 In `argocd/values.yaml`, set `configs.secret.githubSecret:
      "$argocd-webhook-secret:webhook.github.secret"`. Verify
      `helmfile template` in `argocd/` renders that literal under
      `webhook.github.secret` in `argocd-secret`.

## 2. ApplicationSet receiver and preview polling

- [x] 2.1 In `argocd/values.yaml`, add a Traefik `Middleware`
      `appset-webhook` (`replacePath: {path: /api/webhook}`) to
      `extraObjects`. Verify `helmfile template` renders it in `argocd`.
- [x] 2.2 In `argocd/values.yaml`, enable `applicationSet.ingress` with
      `ingressClassName: traefik`, `hostname: argo.lab.kvd.studio`,
      `path: /api/webhook/appset`, `pathType: Exact`,
      `extraHosts: [{name: argo.kvd.studio, path: /api/webhook/appset}]`, and
      annotation `traefik.ingress.kubernetes.io/router.middlewares:
      argocd-appset-webhook@kubernetescrd`. Verify `helmfile template`
      renders an Ingress for both hosts pointing at the ApplicationSet
      controller's webhook port.
- [x] 2.3 In `apps-dev/apps/templates/primerdriver-previews.yaml`, set
      `requeueAfterSeconds: 600`. Verify `helm template apps-dev/apps` renders
      it.
- [x] 2.4 Add `terraform/modules/github_webhook_allowlist/` (`data "http"` on
      `https://api.github.com/meta`, a `cloudflare_ruleset` in phase
      `http_request_firewall_custom` blocking `/api/webhook*` on
      `argo.kvd.studio` unless `ip.src` is in `hooks`) and a `webhook-allowlist`
      unit in `terraform/terragrunt.stack.hcl`. Verify `task tf-plan` shows one
      ruleset created with the GitHub hook CIDRs in its expression, and no
      existing ruleset conflict (import it if there is one).

## 3. Rollout and GitHub webhooks

- [x] 3.1 After merge: run `helmfile apply` in `argocd/` and `task tf-apply`
      in `terraform/`. Verify `argocd-webhook-secret` exists in `argocd`, and
      from the LAN, `curl -si -X POST
      https://argo.lab.kvd.studio/api/webhook/appset` is answered by the
      ApplicationSet controller (its log shows the request), not by
      argocd-server or a Traefik 404.
- [x] 3.2 (Manual, GitHub) In `homelab-automation`, add a webhook to
      `https://argo.kvd.studio/api/webhook`, `application/json`, the secret,
      push events only. Verify the ping delivery returns 200, and a push to
      `main` makes an Application start syncing within 30s.
- [ ] 3.3 (Manual, GitHub) In `primerdriver`, add a webhook to
      `https://argo.kvd.studio/api/webhook/appset`, `application/json`, the
      secret, pull request events only. Verify opening a test PR creates
      `primerdriver-pr-<n>` within 30s and closing it deletes the Application.
      If deliveries fail on signature, the controller does not resolve the
      `$` reference: stop and revisit design.md.
- [x] 3.4 Verify edge auth: from a non-GitHub IP,
      `curl -s -o /dev/null -w '%{http_code}' -X POST` to
      `https://argo.kvd.studio/api/webhook` and `.../api/webhook/appset`
      returns 403, and
      `https://argo.kvd.studio/` still loads.
- [x] 3.5 Verify signature auth: from inside the LAN, an unsigned POST of a
      push payload to `https://argo.lab.kvd.studio/api/webhook` triggers no
      refresh (argocd-server logs a signature error).
- [x] 3.6 Add a short "GitHub webhooks" note to `AGENTS.md` (Deploying
      section): the two endpoints, which repo sends which events, that the
      secret is `GITHUB_WEBHOOK_SECRET` in Infisical project `argocd`, and
      that the endpoints only accept GitHub hook IPs (rerun `task tf-apply`
      if GitHub changes its ranges).
      Verify `prek run --all-files` passes.

## Workflow follow-up

- Archive the change after the webhooks are verified.
