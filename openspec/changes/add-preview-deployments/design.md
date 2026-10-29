# Design

## Context

- `primerdriver/` is a stock `helm create` chart: one Deployment (1 replica,
  amd64-only affinity), a ClusterIP Service on 8000, an Ingress for
  `primerdriver.lab.kvd.studio` and `primerdriver.kvd.studio` with Homepage
  annotations, and readiness/liveness probes on `/api/health`. Its only config
  is `PORT`; it has no secrets, PVCs, or database.
- Argo Rollouts v1.10.1 runs from `argo-rollouts/install.yaml`. No workload uses
  it yet.
- ArgoCD is installed by `argocd/helmfile.yaml` (chart 10.11.3). The
  ApplicationSet and notifications controllers are enabled with default config;
  no notifiers, templates, or triggers exist.
- Internal DNS has `*.lab.kvd.studio` A records to the cluster, and Traefik's
  default TLSStore serves a `*.lab.kvd.studio` certificate, so any one-label
  host under `lab.kvd.studio` resolves and gets TLS with no extra config.
- primerdriver CI (`build-and-push.yml`) builds only on push to `main`, tags
  `sha-<7>` via `docker/metadata-action`, and uses one global concurrency group
  with `cancel-in-progress`.
- Self-hosted Renovate covers `banyuhay`, `hannibot`, `homelab-automation`. The
  primerdriver repo has no Renovate config and no branch protection.

## Goals / Non-Goals

**Goals:**

- A pattern other stateless in-house charts can copy by changing names.
- Reuse native mechanisms (readiness probes, generator templating, notification
  triggers) before adding new objects.

**Non-Goals:**

- Previews for apps with databases or secrets (data isolation is unsolved here).
- Canary or traffic-weighted rollouts.
- Previews for homelab-repo PRs (chart changes); the production gate covers the
  tag bumps those PRs carry.
- Public preview URLs or Cloudflare Access.
- A Rollouts dashboard or ArgoCD UI extension.

## Decisions

### Blue-green, not canary

The chart's Deployment becomes a `Rollout` with `strategy.blueGreen`:
`activeService` is the existing Service, `previewService` is a new
`<fullname>-preview` Service (required by blue-green; not exposed by any
Ingress). The HPA's `scaleTargetRef` points at the Rollout.

Canary with weighted traffic would need Traefik `TraefikService` objects and
more than one replica to mean anything. Blue-green matches Vercel's atomic
switch and needs no ingress integration.

### Health gate from readiness plus `minReadySeconds`, not an AnalysisTemplate

`autoPromotionEnabled` stays at its default (`true`), so Rollouts promotes once
the new ReplicaSet is fully available. `minReadySeconds: 30` makes "available"
mean "ready on `/api/health` for 30 continuous seconds", which delivers the
agreed behavior (automatic promotion after a sustained health check).

An AnalysisTemplate polling the same `/api/health` would duplicate the readiness
probe, and Rollouts skips `prePromotionAnalysis` on a Rollout's first deploy, so
a new preview would get no check from it at all. Readiness applies to every
deploy. An AnalysisTemplate remains the upgrade path once there is a real smoke
test (e.g. a primer-design request) worth running.

### Abort and rollback

- Production: `progressDeadlineSeconds: 300` with `progressDeadlineAbort: true`,
  so a build that never becomes available aborts and the app goes Degraded.
- `scaleDownDelaySeconds: 600` keeps the old ReplicaSet running. Rollback is
  `git revert` of the tag commit: the reverted pod template hashes to the
  still-running ReplicaSet, so Rollouts switches back without starting pods.
  `kubectl argo rollouts undo` edits the Rollout spec and ArgoCD `selfHeal`
  would revert it; `kubectl argo rollouts abort` only touches status, so it is
  the in-cluster break-glass during a rollout.
- These settings are chart values (`rollout.*`), so previews can override them
  (see below).

### Previews: one ApplicationSet, one shared namespace

`apps/apps/templates/primerdriver-previews.yaml`, wrapped in
`disablePrimerDriverPreviews`, defines an ApplicationSet with:

- `goTemplate: true` and a `pullRequest.github` generator on
  `kvdomingo/primerdriver`, `requeueAfterSeconds: 60`, `appSecretName` pointing
  at the GitHub App credentials.
- Application name `primerdriver-pr-{{ .number }}` in project `apps-prod`,
  source `primerdriver/` at homelab `main`, destination namespace
  `primerdriver-preview` (`CreateNamespace=true`), automated sync with prune and
  selfHeal, and the `apps.finalizers` finalizer so deletion cascades.
- `helm.valuesObject` overrides:
  - `image.tag: sha-{{ trunc 7 .head_sha }}`. The generator's `head_short_sha`
    is 8 characters; `docker/metadata-action` tags 7.
  - `ingress.hosts`: only `primerdriver-pr-{{ .number }}.lab.kvd.studio`. Lists
    replace, so the `kvd.studio` host disappears.
  - each `gethomepage.dev/*` annotation set to `null`. Maps merge, so `{}` would
    keep them.
  - `rollout.progressDeadlineAbort: false`, `rollout.progressDeadlineSeconds:
    900`, `rollout.scaleDownDelaySeconds: 0`.

All previews share one namespace because ArgoCD does not delete a namespace it
created through `CreateNamespace`; a namespace per PR would leak one per closed
PR. The chart's fullname helper returns the release name when it contains
`primerdriver`, so `primerdriver-pr-42` yields unique Rollout, Service, Ingress,
and ServiceAccount names.

Previews do not abort: the generator often sees a new head before CI has pushed
its image, so the pod sits in ImagePullBackOff for a while. With abort on, a
slow build would leave the preview permanently aborted. With abort off it goes
Degraded after 15 minutes and recovers to Healthy if the image arrives later.

### Commit status through ArgoCD Notifications

The ApplicationSet template stamps each Application with:

- `preview.kvd.studio/repo-url: https://github.com/kvdomingo/primerdriver`
- `preview.kvd.studio/head-sha: {{ .head_sha }}`
- `preview.kvd.studio/image-tag: sha-{{ trunc 7 .head_sha }}`
- `notifications.argoproj.io/subscribe.on-preview-status.github: ""`

`argocd/values.yaml` adds a `github` notifier, one template per state, and one
trigger `on-preview-status` with three conditions:

| State | Condition | Status |
|---|---|---|
| pending | health `Progressing` | `pending` |
| success | health `Healthy`, sync `Synced`, and `app.status.summary.images` contains the image tag | `success`, `targetURL` = preview URL |
| failure | health `Degraded` and the image tag is present | `failure` |

Each condition uses `oncePer` on the head-sha annotation (plus the state), so a
status posts once per commit per state. The template sets
`repoURLPath`/`revisionPath` to those annotations. The defaults point at
`spec.source.repoURL` and the sync revision, which are the homelab repo and its
`main` commit. The image-tag check stops a still-Healthy previous build from
marking a new commit `success` before its own Rollout has started.

Alternative: a CI job in primerdriver polling the preview URL. GitHub-hosted
runners cannot reach `lab.kvd.studio`, and personal-account self-hosted runners
are per repo, so this would need another runner.

### One GitHub App for the generator and the notifier

The notifications-engine GitHub service only authenticates as a GitHub App
(`GitHubOptions` has `appID`, `installationID`, `privateKey` and no token
field). The pullRequest generator accepts App credentials too, so one App covers
both: installed on `kvdomingo/primerdriver` only, with Metadata read, Pull
requests read, and Commit statuses read/write.

Credentials live in an Infisical project and reach the cluster through
`infisical-secrets/argocd/secret.yaml`, modeled on the existing
InfisicalSecrets, producing two Secrets in `argocd`:

- `argocd-notifications-secret` with `github-appID`, `github-installationID`,
  `github-privateKey`, referenced as `$github-*` from the notifier config. The
  chart's `notifications.secret.create` becomes `false` so Helm stops owning it.
- `github-app-primerdriver`, a repo-creds Secret (`githubAppID`,
  `githubAppInstallationID`, `githubAppPrivateKey`) with `url` set to the full
  `https://github.com/kvdomingo/primerdriver`. A prefix like
  `https://github.com/kvdomingo` would make ArgoCD fetch `homelab-automation`
  with an App that is not installed there.

ArgoCD is not itself an ArgoCD Application, so a small
`core/apps/templates/argocd-secrets.yaml` Application syncs
`infisical-secrets/argocd/` into `argocd`.

### Merge gate

- Branch protection on primerdriver `main` requires `preview/primerdriver`.
  Without it, Renovate could merge on green CI before the preview has reported.
- `renovate/templates/configmap.yaml` adds `kvdomingo/primerdriver`. Its
  onboarding PR adds a `renovate.json` with `automerge: true` for minor and
  patch updates and `automergeType: pr`, matching homelab's approach. Majors
  stay manual.

### primerdriver CI

- Add `pull_request` to `build-and-push.yml`'s triggers.
- Set `DOCKER_METADATA_PR_HEAD_SHA: "true"`. On `pull_request` events
  `docker/metadata-action` otherwise tags the merge commit's SHA, which never
  matches `head_sha`.
- Change concurrency to `build-${{ github.ref }}` so PR builds don't cancel each
  other or the `main` build.

## Risks / Trade-offs

- [Brief production outage on the Deployment-to-Rollout switch: ArgoCD prunes
  the Deployment in the same sync that creates the Rollout] → Accept a
  seconds-long blip for the pilot. Rollouts' `workloadRef` migration avoids it
  and is the path for apps where it matters.
- [Fork PRs cannot push to ghcr, so their previews fail] → Single-maintainer
  repo; accept. A `failure` status on a fork PR is expected.
- [A slow CI build posts `failure`, then `success` when the image arrives] → The
  final status is correct; Renovate waits for success. The 15-minute preview
  deadline makes this rare.
- [Each open PR costs one amd64 pod] → `config:recommended` caps primerdriver at
  10 open Renovate PRs; primerdriver is small.
- [Notification config lives in a helmfile release, outside ArgoCD sync] →
  The apply task includes the manual `helmfile apply`, per AGENTS.md.
- [The gate only proves the app starts and answers `/api/health`] → Upgrade to
  an AnalysisTemplate with a functional smoke test later; the commit status
  plumbing stays the same.

## Migration Plan

1. Create the GitHub App, install it on primerdriver, store its credentials in
   Infisical.
2. Merge `infisical-secrets/argocd/` and the `argocd-secrets` Application;
   confirm both Secrets exist. Merge the `argocd/values.yaml` notifier changes
   and run `helmfile apply` in `argocd/`.
3. Merge the chart's Rollout conversion. Confirm production promotes and
   `primerdriver.kvd.studio` serves.
4. Merge the primerdriver CI change; confirm a PR produces `sha-<head7>`.
5. Merge the ApplicationSet; open a test PR, confirm the preview URL and the
   `preview/primerdriver` statuses, then close it and confirm cleanup.
6. Turn on branch protection, add primerdriver to Renovate, merge its onboarding
   PR.

Rollback: set `disablePrimerDriverPreviews: true` to drop all previews; revert
the chart commit to return to a Deployment; remove the required check in GitHub
if the notifier is broken, so merges are not blocked.
