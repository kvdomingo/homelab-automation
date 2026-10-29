# Design

## Context

- ArgoCD is a helmfile component (`argocd/`, chart `argo-cd` 10.11.6). The
  chart creates `argocd-secret` (`configs.secret.createSecret: true`), which
  also holds the admin password and `server.secretkey`.
- `argo.kvd.studio` is already public. The Cloudflare tunnel maps every name
  in `lab_kvd_studio_subdomains` to `https://<name>.lab.kvd.studio` (Traefik),
  and the server ingress lists `argo.kvd.studio` in `extraHosts`. No webhook
  secret is set today.
- `infisical-secrets/argocd/secret.yaml` (synced by
  `core/apps/templates/argocd-secrets.yaml`) already materializes
  `argocd-notifications-secret` and the `github-app-primerdriver` repo creds
  from Infisical project `argocd`, env `prod`.
- The ArgoCD server and the ApplicationSet controller are separate webhook
  receivers. Both serve the fixed path `/api/webhook`, so they cannot share a
  host without path rewriting.

## Goals / Non-Goals

**Goals:**

- Push and pull request events reach the right receiver, signed, with polling
  kept as a fallback.

**Non-Goals:**

- Webhooks for repos other than `homelab-automation` and `primerdriver`. Add
  them when another repo gets an Application or a preview ApplicationSet.
- Managing GitHub webhooks as code. There are two, set once.
- Shortening or removing `timeout.reconciliation`.

## Decisions

### Webhook secret: reference from `argocd-secret` to an Infisical secret

Set `configs.secret.githubSecret` to
`$argocd-webhook-secret:webhook.github.secret`. ArgoCD resolves a
`$<name>:<key>` value to that key of another Secret in its namespace, if the
Secret has the label `app.kubernetes.io/part-of: argocd`. A new
`managedKubeSecretReferences` entry in `infisical-secrets/argocd/secret.yaml`
creates `argocd-webhook-secret` from `GITHUB_WEBHOOK_SECRET`, with that label.

- Alternative: let Infisical own all of `argocd-secret`
  (`createSecret: false`). Rejected: ArgoCD writes a generated
  `server.secretkey` into that Secret, and the Infisical resync would remove
  it, ending every session every 10s.
- Alternative: put the secret into `values.yaml`. Rejected: plaintext secret
  in git.
- One secret for both repos. The two webhooks have the same trust level, and
  ArgoCD has only one `webhook.github.secret` slot anyway.

### ApplicationSet receiver at `/api/webhook/appset` on the ArgoCD host

Enable `applicationSet.ingress` with class `traefik`, hostname
`argo.lab.kvd.studio`, `extraHosts: argo.kvd.studio`, path
`/api/webhook/appset`, `pathType: Exact`. A Traefik `Middleware`
`appset-webhook` (`replacePath: {path: /api/webhook}`) rewrites the path
before it reaches the controller; it ships through the chart's `extraObjects`
and is attached with the ingress annotation
`traefik.ingress.kubernetes.io/router.middlewares:
argocd-appset-webhook@kubernetescrd`.

Traefik ranks routers by rule length, so this exact-path rule wins over the
server ingress's `/` prefix on the same host.

- Alternative: a separate host `argo-appset.kvd.studio`. Rejected: one more
  public hostname, tunnel route, and DNS record for a single path.
- Everything stays in `argocd/values.yaml`; no Terraform change for routing.

### Edge auth: Cloudflare WAF allowlist of GitHub hook IPs

The signature check runs inside ArgoCD, so unsigned requests still reach the
cluster. A Cloudflare custom WAF rule on the `kvd.studio` zone blocks them at
the edge:

```text
http.host eq "argo.kvd.studio"
and starts_with(http.request.uri.path, "/api/webhook")
and not ip.src in {<GitHub hook CIDRs>}
→ block
```

The CIDRs come from the `hooks` list of `https://api.github.com/meta`, read
with a `data "http"` source at plan time, so each `tf-apply` picks up changes
to GitHub's ranges. The rule lives in a new module
`terraform/modules/github_webhook_allowlist/` (a `cloudflare_ruleset` in phase
`http_request_firewall_custom`) and a new unit `webhook-allowlist` in the
stack, following the one-unit-per-concern layout. The tunnel keeps the real
client IP at the edge, so `ip.src` is GitHub's address.

- Alternative: Cloudflare Access on the webhook paths. Rejected: GitHub
  webhooks cannot send a service token or any custom header.
- Alternative: hardcode the CIDRs. Rejected: they change, and a stale list
  silently drops deliveries.
- Alternative: a `cloudflare_list` of IPs referenced as `$list`. Rejected: one
  more resource for about ten CIDRs that fit in the expression.
- The signature check stays. The IP check only proves a request came from
  GitHub, not from these repos; any GitHub user can point a webhook at these
  URLs.

### Repo webhooks, not the GitHub App webhook

Create a repo webhook in each repo (content type `application/json`, the
shared secret, SSL verification on):

| Repo | Payload URL | Events |
| --- | --- | --- |
| `homelab-automation` | `https://argo.kvd.studio/api/webhook` | push |
| `primerdriver` | `https://argo.kvd.studio/api/webhook/appset` | pull requests |

- Alternative: the webhook of the existing GitHub App. Rejected: an App has
  one webhook URL, but the two repos need different receivers, and the App is
  installed on `primerdriver` only.

### Preview poll interval 60s → 600s

With webhooks driving previews, the poll is only a fallback. 600s cuts GitHub
API calls by 10x and still recovers a missed delivery within 10 minutes.

## Risks / Trade-offs

- [The ApplicationSet controller may not resolve `$name:key` references for
  the webhook secret] → Task 3.3 checks it with a test delivery. If it fails,
  stop and revisit this design before going further.
- [`/api/webhook/appset` exposes the controller's webhook port to the
  internet] → Only GitHub IPs get through the WAF, the controller only
  accepts signed payloads, and the endpoint can only trigger a re-run of
  generators, never a write of arbitrary state.
- [The middleware is missing or misnamed, so the controller gets
  `/api/webhook/appset` and answers 404] → Task 3.1 checks the rewritten
  route before the GitHub webhook is created.
- [The zone already has an entry-point ruleset for
  `http_request_firewall_custom` (from rules made in the dashboard), so
  creating one fails] → Task 2.4 checks `tf-plan`; if one exists, import it
  and carry its rules into the module.
- [GitHub adds a hook range before the next `tf-apply`] → Deliveries from the
  new range get 403 and polling covers the gap; GitHub shows the failed
  deliveries. Rerun `task tf-apply` to refresh the list.
- [Webhook created before the secret is live causes failed deliveries] →
  Create the GitHub webhooks last; GitHub shows failed deliveries and they
  can be redelivered.

## Migration Plan

1. Add `GITHUB_WEBHOOK_SECRET` (random, 32+ bytes) to Infisical.
2. Merge the repo changes. ArgoCD syncs the InfisicalSecret and the preview
   ApplicationSet. Run `helmfile apply` in `argocd/` and `task tf-apply` in
   `terraform/`.
3. Create the two GitHub webhooks.

Rollback: delete the GitHub webhooks. Polling continues to work. Revert the
commit, run `helmfile apply` to remove the ingress, middleware, and secret
reference, and `task tf-apply` to remove the WAF rule.
