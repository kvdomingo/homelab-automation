# Proposal

## Why

Keel restarts workloads onto new `latest` images outside of git. That bypasses
ArgoCD sync hooks: LiteLLM prod broke because the image moved ahead of its
database schema, and its migration job only runs on a git-triggered sync.
Version changes should land as git commits, so ArgoCD deploys them like any
other change, they show up in history, and a revert rolls them back.

## What Changes

- Add a repo-level Renovate config to `homelab-automation`, and add the repo to
  the self-hosted Renovate's `repositories` list.
- Track every version format the repo uses: Helm chart versions in ArgoCD
  `Application` templates (`targetRevision`, both Helm-repo and OCI sources),
  `image.repository` + `image.tag` pairs in in-house `values.yaml` and inline
  `valuesObject`s, inline `image: repo:tag` strings, Helm chart dependencies,
  helmfiles, `docker-compose.yaml`, and GitHub Actions.
- Grouping: one PR for all patch updates, one PR for all minor updates, both
  auto-merged. One PR per application for major updates, never auto-merged.
- Own images (`ghcr.io/kvdomingo/*`), which publish no versions, are pinned to
  their commit tag (`sha-cf6d19f`), which follows the source repo's default
  branch. `postgresql-pig`, which is rebuilt weekly from the same commit, is
  pinned as `18@sha256:<digest>`. Each application gets its own auto-merged
  update PR.
- **BREAKING**: replace every floating tag (`latest`, `stable`,
  `latest-alpine`, untagged `image:`) with a concrete version, or with a
  commit tag or digest pin for own images. After this, nothing updates until
  Renovate opens a PR.
- Remove all `keel.sh/*` annotations. The Keel `Application` stays installed,
  with its image pinned.
- Fix the Renovate CronJob, which ignores `image.tag` and so runs an implicit
  `latest`.
- Update the `AGENTS.md` image convention from "`latest` + Keel" to "pinned tag,
  updated by Renovate".

## Capabilities

### New Capabilities

- `dependency-updates`: how image and chart versions in this repo are pinned,
  tracked, grouped into PRs, auto-merged or gated, and deployed.

### Modified Capabilities

## Impact

- New: root `renovate.json5`.
- `renovate/` chart: global `repositories` list, CronJob image reference, Keel
  annotation removal.
- ~25 files with Keel annotations: in-house `<app>/values.yaml`, and
  `apps/apps/templates/*.yaml` / `core/apps/templates/*.yaml` with inline
  values.
- ~26 floating-tag occurrences and untagged `image:` refs (e.g. `busybox` in
  Helm test hooks, `traefik:v3` in `bind9/docker-compose.yaml`).
- Deployment flow: merged Renovate PRs reach the cluster through ArgoCD
  auto-sync. Components installed with `helmfile` (`argocd/`, `infisical/`,
  `promstack/`, `core-services/`, `arrstack/`) still need a manual
  `helmfile apply` after merge.
- Running pods may change image on first sync, when pinned versions differ from
  the cached `latest` digests.
