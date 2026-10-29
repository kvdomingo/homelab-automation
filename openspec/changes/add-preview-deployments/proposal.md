# Proposal

## Why

Apps deploy straight to production: a merged tag bump replaces the running pods,
nothing checks the new build before it takes traffic, and the only way to try a
change before merging is to run it locally. Argo Rollouts is already installed
but unused. Piloting Vercel-style production and preview deployments on
primerdriver (stateless, no secrets) proves the pattern before other apps adopt
it, and lets a healthy preview gate Renovate's auto-merges in the app repo.

## What Changes

- primerdriver's production workload becomes a blue-green Argo Rollout: a new
  build starts beside the current one, takes traffic only after it has stayed
  healthy, and the previous version stays warm for a fast rollback.
- Every open pull request on `kvdomingo/primerdriver` gets its own preview
  environment at `primerdriver-pr-<n>.lab.kvd.studio`, running that PR's head
  commit and removed when the PR closes.
- Each preview reports its result to the PR as a commit status
  (`preview/primerdriver`), which is a required check on primerdriver `main`.
- Self-hosted Renovate starts covering `kvdomingo/primerdriver`; its dependency
  PRs there auto-merge only after the preview check passes.
- A GitHub App gives ArgoCD read access to primerdriver PRs and write access to
  its commit statuses. Its credentials come from Infisical.
- Cross-repo and manual work this change depends on: primerdriver CI builds an
  image for every PR, primerdriver gets a Renovate config and branch
  protection, and the GitHub App is created by hand.

## Capabilities

### New Capabilities

- `progressive-delivery`: how a production workload switches to a new build:
  health-gated promotion, automatic abort, and rollback.
- `preview-deployments`: per-PR preview environments for an app repo, their
  lifecycle and addressing, and the commit status that gates merges.

### Modified Capabilities

- `dependency-updates`: preview environments run PR images that are not pinned
  in, or changed through, this repo's `main`; the pinning and git-only version
  change requirements gain an explicit exemption for them.

## Impact

- `primerdriver/` chart: Deployment replaced by a Rollout, new preview Service,
  HPA target updated.
- New `apps-dev/apps/templates/primerdriver-previews.yaml` (ApplicationSet).
- `argocd/values.yaml`: GitHub notifier, template, and trigger; Infisical owns
  the notifications secret. Needs a manual `helmfile apply` after merge.
- New `infisical-secrets/argocd/` and an Application that syncs it.
- `renovate/templates/configmap.yaml`: add `kvdomingo/primerdriver`.
- Outside this repo: `kvdomingo/primerdriver` CI workflow, `renovate.json`,
  branch protection; a new GitHub App on the `kvdomingo` account.
- Cluster load: one extra primerdriver pod per open PR, on amd64 nodes only.
