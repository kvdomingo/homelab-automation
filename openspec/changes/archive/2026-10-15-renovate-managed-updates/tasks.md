# Tasks

## 1. Renovate runtime

- [x] 1.1 Change the CronJob image in `renovate/templates/job.yaml` to
      `{{ .Values.image.repository }}:{{ .Values.image.tag }}`, pin
      `renovate/values.yaml` `image.tag` to the running full version, and remove
      its `keel.sh/*` `jobAnnotations`. Verify with `helm template renovate`
      that the image renders with the full tag and the CronJob has no Keel
      annotations
- [x] 1.2 Add `kvdomingo/homelab-automation` to `repositories` in
      `renovate/templates/configmap.yaml`. Verify the rendered `config.json5`
      lists all three repos
- [x] 1.3 Confirm the Renovate token (Infisical `renovate` project) can write
      contents, PRs, and issues on `homelab-automation`. Verify by checking the
      token's repo access in GitHub settings, or by finding no permission errors
      in the first run's logs (5.1)

## 2. Repo config

- [x] 2.1 Create `renovate.json5` with the built-in manager
      `managerFilePatterns` from design D2 (`kubernetes` on `longhorn/**`,
      `argo-rollouts/**`, `**/templates/**/*.yaml`). Verify with
      `npx --yes --package renovate -- renovate-config-validator renovate.json5`
- [x] 2.2 Add `customManagers` for Application `targetRevision` (Helm repo and
      OCI), `valuesObject` `repository`+`tag` pairs, and the `# renovate:`
      annotation comment. Verify with
      `npx --yes renovate --platform=local --dry-run=lookup` (output to a
      scratch log) that every vendor chart in `apps/apps/templates` and
      `core/apps/templates` is detected, e.g. `litellm-helm 1.102.0`,
      `vaultwarden 0.35.1`, `dagster 1.12.21`
- [x] 2.3 Add `packageRules` for the patch group (patch/pin/digest,
      automerge), the minor group (automerge), and per-app
      majors (no automerge, `additionalBranchPrefix` per D3, app named in the
      title). Verify with the local dry run: proposed branches are
      `renovate/patch-updates`, `renovate/minor-updates`, and one major branch
      per app file or directory
- [x] 2.4 Add the `git-refs` annotation manager for own `sha-<short>` tags (D2)
      and the own-image rule (D3 rule 4: `ghcr.io/kvdomingo/**` and
      `https://github.com/kvdomingo/**`, digest, per-app branch, automerge,
      placed after the patch rule). Verify with the local dry run, after 3.2,
      that each own image is detected with its short SHA, that an up-to-date pin
      proposes nothing, that a pin set to an older `sha-` tag proposes the
      branch head as `sha-<7 chars>` on its own per-app branch, and that none
      appear in `renovate/patch-updates`
- [x] 2.5 Add `versioning` overrides or ignores for unusual tag schemes found in
      the dry run (e.g. `ubuntu/bind9`, `version-x.y.z`). Verify the dry run
      shows no `Failed to look up` or invalid-version warnings for repo deps

## 3. Pin floating tags

- [x] 3.1 Write a table (`pins.md`, for the PR description) of every floating or
      untagged image (`grep -rnE 'tag:\s*"?(latest|stable|latest-\w+)"?$'` plus
      untagged `image:` refs, including `busybox` test hooks, `traefik:v3`, and
      `alpine:3.17`), with the version picked per D5 from the running pod's
      digest. Verify that every grep hit has a row
- [x] 3.2 Pin own images per D5: `primerdriver/values.yaml`,
      `excalidraw/values.yaml`, and `apps/apps/templates/delphitools.yaml` to
      the `sha-<short>` tag matching the running digest, with a trailing
      `# renovate: datasource=git-refs depName=https://github.com/kvdomingo/<repo> branch=<main|master>`
      comment; `umami/templates/deployment.yaml` to
      `ghcr.io/kvdomingo/postgresql-pig:18@sha256:<running digest>`. For any
      third-party image with no version tags, stop and ask the user. Verify that
      `crane digest` of each pinned `sha-` tag equals the running pod's
      `imageID`, and that the local dry run detects all four
- [x] 3.3 Pin core components (`core/apps/templates/*.yaml` including
      `keel.yaml`, `traefik/`, `infisical/`, `argocd/`). Verify that `grep`
      finds no floating tags in those paths and that `helm template` /
      `helmfile template` renders
- [x] 3.4 Pin in-house charts (`<app>/values.yaml`, Helm test-hook `busybox`).
      Verify with `helm template <app>` for each changed chart and an empty
      floating-tag grep for those paths
- [x] 3.5 Pin `apps/apps/templates/*.yaml` `valuesObject` images, adding
      `# renovate:` comments where only `tag:` is set (e.g. `vaultwarden`,
      `home-assistant`, `tailscale`, `portainer`, `cloudflare`). Verify with
      `helm template apps/apps` and an empty floating-tag grep
- [x] 3.6 Pin `bind9/docker-compose.yaml`, `longhorn/`, and `argo-rollouts/`
      inline images. Verify with
      `docker compose -f bind9/docker-compose.yaml config` and an empty
      floating-tag grep across the repo

## 4. Remove Keel annotations

- [x] 4.1 Remove all `keel.sh/*` annotations, including the commented-out block
      in `dagster.yaml`, and drop any annotation maps left empty. Keep
      `secrets.infisical.com/auto-reload` and the Keel `Application`. Verify
      that `grep -rn 'keel.sh' --include='*.yaml' .` returns nothing and that
      `core/apps/templates/keel.yaml` still exists
- [x] 4.2 Run `pre-commit run --all-files`. Verify that it passes

## 5. Rollout and verification

- [x] 5.1 Push sections 1–2. After the next hourly run, verify that the
      Dependency Dashboard issue exists on `homelab-automation` and lists every
      chart and image, with no errors or undetected deps
- [x] 5.2 Push the pinning and Keel batches one at a time (3.3 → 3.4 → 3.5/3.6
      with 4.1). Verify after each that every affected ArgoCD app is
      Synced/Healthy, with no unexpected image changes beyond the 3.1 table
- [x] 5.3 Verify that the first patch and minor group PRs are auto-merged and
      deployed by ArgoCD, and that a major PR stays open for manual merge
- [x] 5.4 After the next commit to an own image's repo (e.g. delphitools),
      verify that Renovate opens and auto-merges a PR changing just that app's
      `sha-` tag, and that ArgoCD rolls it out. After the next weekly
      `postgresql-pig` rebuild, verify the same for its digest
- [x] 5.5 Verify Keel is idle: Keel logs show no updates after rollout

## 6. Docs

- [x] 6.1 Update the `AGENTS.md` conventions: images use a pinned version tag
      updated by Renovate PRs (patch/minor auto-merged, majors per app need a
      manual merge), own `ghcr.io/kvdomingo/*` images are pinned to
      `sha-<short>` with a `git-refs` `# renovate:` comment and auto-updated by
      per-app PRs (`postgresql-pig` by digest), `# renovate:` comments where
      only `tag:` is set, and run `helmfile apply` after merges that touch
      helmfile components. Verify that the Keel line no longer appears in the
      conventions
