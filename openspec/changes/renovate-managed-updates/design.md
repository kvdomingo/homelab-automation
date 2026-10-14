# Design

## Context

- Renovate already runs in-cluster: the `renovate/` chart is a `@hourly`
  CronJob with a global config in `renovate/templates/configmap.yaml`
  (`config:recommended`, `separateMinorPatch: true`, `onboarding: true`). It
  only processes `kvdomingo/banyuhay` and `kvdomingo/hannibot`. Its token comes
  from the Infisical `renovate` project.
- The CronJob container uses `image: {{ .Values.image.repository }}`, so
  `tag: "43"` is ignored and the job runs an implicit `latest`.
- Versions are written in several shapes:
  - `apps/apps/templates/*.yaml` and `core/apps/templates/*.yaml` are ArgoCD
    `Application`s wrapped in `{{- if not .Values.disable<Name> }}`. Because of
    that wrapper they are not valid YAML, so Renovate's built-in `argocd`
    manager can't parse them. Chart versions there are `targetRevision`
    alongside `repoURL` + `chart` (Helm repo) or `repoURL: oci://…` +
    `path: .` (OCI).
  - Inline `valuesObject`s in those templates set images as
    `repository` + `tag`, or `tag` alone. With `tag` alone the repository comes
    from the chart default (e.g. `vaultwarden.yaml`, `home-assistant.yaml`).
  - In-house charts: `<app>/values.yaml` (`image.repository` / `image.tag`) and
    `<app>/Chart.yaml` `dependencies`.
  - `helmfile.yaml` in `argocd/`, `infisical/`, `promstack/`, `core-services/`,
    and `arrstack/`.
  - Inline `image: repo:tag` in plain manifests (`longhorn/`,
    `argo-rollouts/install.yaml`), Helm test hooks (`busybox`), and
    `bind9/docker-compose.yaml`.
  - `.github/workflows/*.yaml` `uses:`.
- No GitHub checks run on PRs. The only workflows are deploy jobs triggered by
  pushes to `main`.
- Keel annotations live in about 24 files. `core/apps/templates/keel.yaml` is
  Keel itself.

## Goals / Non-Goals

**Goals:**

- Put the whole config in one repo-level file, using built-in managers wherever
  they parse the file and regex managers only where they don't.
- Make the move to pinned versions without surprise up- or downgrades.

**Non-Goals:**

- Uninstalling Keel.
- Adding PR CI such as `helm template` or kubeconform. Auto-merge doesn't
  depend on it (see D4).
- Tracking `targetRevision: main` / `HEAD` sources: in-house charts and the
  user's app repos.
- Ansible role versions, Terraform providers, and `mise.toml`.
  `config:recommended` may still detect these, and they then follow the same
  grouping rules. Nothing here adds or blocks them.

## Decisions

### D1: Repo-level `renovate.json5`, plus adding the repo to the global list

The repo's rules go in `renovate.json5` at the repo root. Global settings stay
in the ConfigMap, which only gains `kvdomingo/homelab-automation` under
`repositories`. Because a config file already exists, Renovate skips the
onboarding PR.
*Alternative*: everything in the global ConfigMap. Rejected because it would
apply these rules to the other two repos, and changing it means an ArgoCD sync
rather than just a commit.

### D2: Managers

| Format | Manager |
|---|---|
| `<app>/values.yaml` | built-in `helm-values` (matches by default) |
| `Chart.yaml` dependencies | built-in `helmv3` |
| `helmfile.yaml` | built-in `helmfile` |
| `docker-compose.yaml` | built-in `docker-compose` |
| Workflows | built-in `github-actions` |
| Plain manifests and Helm templates with `image: repo:tag` | built-in `kubernetes`, with `managerFilePatterns` set to `longhorn/**`, `argo-rollouts/**`, `**/templates/**/*.yaml` |
| Application `targetRevision` (Helm repo) | `customManagers` regex: `repoURL` → `chart` → `targetRevision`, datasource `helm` |
| Application `targetRevision` (OCI) | `customManagers` regex: `repoURL: oci://…` → `path` → `targetRevision`, datasource `docker` |
| `repository` + `tag` in `valuesObject` | `customManagers` regex on adjacent `repository:` / `tag:` lines in `apps/*/templates/*.yaml`, datasource `docker` |
| `tag: <tag>@sha256:<digest>` | all of the above capture an optional `@(?<currentDigest>sha256:[a-f0-9]+)` after the tag |
| `tag:` with no `repository:` | one-line `# renovate: datasource=docker depName=<repo>` comment above the tag, caught by a generic annotation regex manager |
| Own `tag: sha-<short>` | a trailing `# renovate: datasource=git-refs depName=https://github.com/kvdomingo/<repo> branch=<default branch>` comment on the `tag:` line. The manager captures the short SHA as `currentDigest`, sets `currentValue` to the branch, and writes back `sha-{{newDigestShort}}` via `autoReplaceStringTemplate`. The comment sits on the same line because the replacement template can't carry a captured indent (Renovate only passes its own fields to templates) |

All Application templates write `repoURL` → `chart`/`path` → `targetRevision`
in that order, and `repository:` → (`pullPolicy:`/comment lines) → `tag:`, so
the regexes only accept that order. Renovate uses RE2, which has no lookahead.
`config:recommended` ignores `**/tests/**`, so the repo config resets
`ignorePaths` to keep Helm test-hook images tracked.
*Alternative*: fix the YAML validity so the built-in `argocd` manager works
(move the `if` into the app-of-apps values). Rejected: it changes the pattern
used by all 50 templates, and it still wouldn't cover `valuesObject` images.

### D3: Grouping

`packageRules`:

1. `matchUpdateTypes: [patch, pin, digest]` → `groupName: "patch updates"`,
   `automerge: true`.
2. `matchUpdateTypes: [minor]` → `groupName: "minor updates"`,
   `automerge: true`.
3. `matchUpdateTypes: [major]` → `automerge: false`, grouped per app:
   `groupName: "major updates"`, `groupSlug: "updates"`, and an
   `additionalBranchPrefix` naming the app, computed from `packageFile` with
   Renovate's `replace` helper:
   - `apps/*/templates/<app>.yaml` and `core/apps/templates/<app>.yaml` →
     `<app>`. Each Application file is its own app.
   - Anything else → its top-level directory, so `<app>/values.yaml`,
     `<app>/Chart.yaml`, and `<app>/templates/**` land in one PR.
   - `commitMessageSuffix` adds the same name to the PR title.

4. `matchPackageNames: ["ghcr.io/kvdomingo/**", "https://github.com/kvdomingo/**"]`,
   `matchUpdateTypes: [digest]` → `automerge: true`, `groupName: "own image"`,
   and the same per-app `additionalBranchPrefix` as majors, giving
   `renovate/<app>-own-image`. This rule comes after rule 1 so it overrides the
   patch group's `digest` match. A rule before it disables the `docker` lookup
   of `ghcr.io/kvdomingo/*` deps whose tag is `sha-*`, since `git-refs` tracks
   those.

The repo config sets `separateMinorPatch: false`, overriding the global `true`.
With `true`, Renovate prefixes patch branches with `patch-` but not digest or
pin branches, so the patch group would split into two PRs. The cost: a dep
with both a patch and a minor available only gets the minor, in the minor PR.
*Alternative*: majors per package, which is Renovate's default. Rejected
because one app with a chart major and an image major would get two PRs.

### D4: Auto-merge without CI

Patch and minor groups set `automerge: true`, `ignoreTests: true`,
`automergeType: "pr"`. With no status checks, Renovate would otherwise wait
forever. Nothing in the repo blocks a merge, and ArgoCD sync health acts as the
post-merge check.
*Alternative*: add a `helm template` / kubeconform workflow first. That's
deferred, and adding one later only means removing `ignoreTests`.

### D5: Choosing pinned versions

For each floating tag, pin the version the workload is running now. Find it by
matching the running pod's `imageID` digest to a registry tag (`crane ls` /
`crane digest`). If no versioned tag has that digest, use the newest stable
release. Then Renovate's first PRs carry the actual upgrades, instead of the
pinning commit hiding them.
Own images (`ghcr.io/kvdomingo/*`) publish no versions. Their CI
(`docker/metadata-action` `type=sha`) tags each build with the 7-character
commit SHA, plus `latest`:

- `primerdriver` (`main`), `delphitools` (`main`), and `excalidraw` (`master`)
  build on every push to the default branch, so each commit has a `sha-<short>`
  tag. They are pinned to the `sha-` tag whose digest matches the running pod,
  and tracked with the `git-refs` datasource on the source repo (D2). Docker
  tags can't be ordered, so the source repo's branch head is what tells
  Renovate which `sha-` tag is newest.
- `postgresql-pig` builds only on path-filtered pushes and rebuilds weekly from
  the same commit, so a commit doesn't always get a new tag, and one tag can
  move to a new digest. It is pinned as `18@sha256:<digest>` and gets docker
  digest updates. Kubernetes accepts `repo:tag@digest`, so the chart needs no
  change.

Any other third-party image with no version tags is settled one at a time with
the user.

### D6: Removing Keel

Delete every `keel.sh/*` annotation and every now-empty `deploymentAnnotations`
/ `jobAnnotations` map. Keep `secrets.infisical.com/auto-reload`. Leave
`core/apps/templates/keel.yaml` in place, pinning its image under D5.

### D7: Renovate pins itself

The CronJob image becomes
`{{ .Values.image.repository }}:{{ .Values.image.tag }}`, and `tag: "43"`
becomes the running `44.157.0` (the implicit `latest` had already moved to
44), so Renovate also updates its own image through the same groups.

## Risks / Trade-offs

- [Pinning changes running images on first sync] → D5 pins the running digest.
  Roll out in batches (see Migration Plan) and watch ArgoCD health.
- [Auto-merged update breaks an app, with no CI] → Auto-merge only covers
  patch/minor. Revert the merge commit and ArgoCD rolls back. Add PR CI later if
  this happens often.
- [Helmfile components drift: a merged PR changes git but not the cluster until
  someone runs `helmfile apply`] → Accepted. `AGENTS.md` says to apply after a
  merge touching those directories.
- [App migrations, e.g. LiteLLM schema] → These are now tied to chart bumps, so
  ArgoCD PreSync hooks run. This is the main reason for the change.
- [Unusual tag schemes such as `ubuntu/bind9:9.20-24.10_beta`,
  `*-debian-12-rN`, `version-1.6.1`] → Docker versioning handles the suffixes
  of the form `-debian-12-rN`. The others get a per-package `versioning: regex:`
  rule, or they're pinned and ignored with a comment.
- [An own image's commit breaks the app, and its PR auto-merges] → Same as
  before with Keel, except it's now a revertible commit. If that's not enough,
  flip the rule 4 `automerge` to `false`.
- [`git-refs` sees the commit before CI has pushed `sha-<new>`, or the build
  fails] → The new pod sits in `ImagePullBackOff` while the old ReplicaSet keeps
  serving. kubelet keeps retrying, so a late build recovers by itself. A failed
  build leaves the app Degraded in ArgoCD until a fixing commit's PR merges.
  Renovate runs hourly and the builds take minutes, so the race is rare.
- [Renovate compares a 7-character `currentDigest` with a 40-character commit
  SHA] → Verify in the dry run that a current pin proposes no update. If it
  does, store the full SHA in the annotation comment and template the tag from
  it.
- [A source repo changes its default branch or its tagging] → The `branch=` in
  the annotation comment and the `sha-` prefix have to change with it.
- [`bitnamilegacy/*` is frozen] → Renovate finds no updates, which is expected.
- [Token scope] → If the Renovate token is a fine-grained PAT, it needs
  contents, PR, and issues write on `homelab-automation`.

## Migration Plan

1. Fix the Renovate image (D7), add the repo to the global list, and add
   `renovate.json5`. Merge, wait for a run, and check the Dependency Dashboard
   issue for detection gaps. Floating tags are ignored for now, so no PRs show
   up for them.
2. Pin floating tags and remove Keel annotations in batches: core components,
   in-house charts, then Application templates. Push each batch and confirm the
   apps are Synced/Healthy before the next.
3. Update `AGENTS.md`.
4. Watch the first patch, minor, and major PRs to confirm grouping and
   auto-merge.

Rollback: revert the batch commit. Keel is still installed, so restored
annotations work again right away.

## Open Questions

- Should GitHub "Allow auto-merge" be turned on for the repo
  (`platformAutomerge`)? If it's off, Renovate merges the PR itself, so either
  setting works.
