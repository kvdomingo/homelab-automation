# Spec Delta

## Purpose

Keep container images, Helm charts, and other pinned dependencies in this GitOps
repo current through reviewed git changes, so every version change in the
cluster has a commit behind it.

## ADDED Requirements

### Requirement: Versions are pinned in git
Every container image and Helm chart the repo deploys SHALL reference a concrete
version. Floating tags (`latest`, `stable`, `latest-<variant>`, a bare major
like `v3`) and untagged image references SHALL NOT be used. Charts that are
built from this repo itself (`targetRevision: main` / `HEAD` on the
`homelab-automation` repo or the user's own app repos) are exempt.

#### Scenario: Floating tag rejected
- **WHEN** a manifest, values file, or `valuesObject` sets an image tag to `latest`, `stable`, or another non-version tag
- **THEN** the change does not meet this requirement and the tag MUST be replaced with a concrete version that upstream publishes

#### Scenario: Untagged image
- **WHEN** an `image:` string has no tag (e.g. `busybox`)
- **THEN** it MUST be given a concrete version tag

#### Scenario: Own image tagged by commit
- **WHEN** an image is under `ghcr.io/kvdomingo/` and its CI tags every build of the default branch with the short commit SHA
- **THEN** it MUST be pinned to that tag, e.g. `sha-cf6d19f`, not `latest`

#### Scenario: Own image rebuilt without a new commit
- **WHEN** an own image is rebuilt on a schedule from the same commit (`postgresql-pig`)
- **THEN** it MUST be pinned to its tag plus digest, e.g. `18@sha256:<digest>`

### Requirement: Version changes only come from git
The cluster SHALL NOT change a workload's image or chart version except through
a commit to `main` that ArgoCD (or a manual `helmfile apply`) deploys. No
workload SHALL carry `keel.sh/*` annotations.

#### Scenario: New upstream image published
- **WHEN** upstream publishes a new version of an image a workload uses
- **THEN** the running workload keeps its current version until a commit changing that version is merged to `main`

#### Scenario: Keel still installed
- **WHEN** the Keel controller is running in the cluster
- **THEN** it updates no workload, because no workload opts in through annotations

### Requirement: Every version format is tracked
Renovate SHALL detect available updates for each version format in the repo:
- Helm chart `targetRevision` in ArgoCD `Application` templates, for Helm-repo and OCI sources
- `image.repository` / `image.tag` pairs (and `registry` where present) in in-house `values.yaml` and inline `valuesObject`
- Inline `image: <repo>:<tag>` strings in manifests, Helm templates, and `docker-compose.yaml`
- Helm chart `dependencies` in `Chart.yaml`, and charts in `helmfile.yaml`
- GitHub Actions `uses:` references

#### Scenario: Chart in an Application template
- **WHEN** a newer version of a vendor chart referenced by `targetRevision` in `apps/apps/templates/*.yaml` or `core/apps/templates/*.yaml` is published
- **THEN** Renovate proposes the new version, even though the template file contains Go template directives

#### Scenario: Image in values
- **WHEN** a newer version of an image set via `image.repository` + `image.tag` is published
- **THEN** Renovate proposes updating `image.tag`

#### Scenario: Dependency Dashboard coverage
- **WHEN** Renovate runs against the repo
- **THEN** its Dependency Dashboard lists every pinned image and chart, and none appear under errors or as undetected

### Requirement: Patch updates are grouped and auto-merged
All pending patch-level updates across the repo SHALL be combined into a single
PR, which SHALL be merged without human action.

#### Scenario: Several patch updates available
- **WHEN** patch updates are available for three different apps
- **THEN** Renovate opens one PR containing all three, and merges it automatically

### Requirement: Minor updates are grouped and auto-merged
All pending minor-level updates across the repo SHALL be combined into a single
PR, separate from the patch PR, which SHALL be merged without human action.

#### Scenario: Patch and minor updates available together
- **WHEN** one app has a patch update and another has a minor update
- **THEN** Renovate opens two PRs, one for patches and one for minors, and merges both automatically

### Requirement: Major updates are per application and need approval
Major-level updates SHALL be opened as one PR per application, and SHALL NOT be
merged without a human merging the PR. An application is one ArgoCD
`Application` file, in-house chart directory, or other top-level component
directory.

#### Scenario: Two apps with major updates
- **WHEN** major updates are available for two different apps
- **THEN** Renovate opens two separate PRs and leaves both open until a human merges them

#### Scenario: One app with several major updates
- **WHEN** one app has major updates for its chart and for an image it sets
- **THEN** both updates appear in that app's single major PR

### Requirement: Own images update by commit, per application
For images under `ghcr.io/kvdomingo/`, Renovate SHALL propose the newest build:
for a `sha-<short>` tag, the tag of the source repo's latest default-branch
commit; for a `<tag>@sha256:<digest>` pin, the tag's new digest. Each
application SHALL get its own PR, separate from the patch, minor, and major PRs.
These PRs SHALL be merged without human action.

#### Scenario: New commit on an own image's repo
- **WHEN** a commit lands on `kvdomingo/delphitools` `main` and CI pushes `ghcr.io/kvdomingo/delphitools:sha-<new>`
- **THEN** Renovate opens a PR that changes only delphitools' tag to `sha-<new>`, and merges it automatically

#### Scenario: Pinned tag already current
- **WHEN** the pinned `sha-<short>` matches the source repo's latest default-branch commit
- **THEN** Renovate proposes no update for that image

#### Scenario: Scheduled rebuild of the same commit
- **WHEN** CI rebuilds `ghcr.io/kvdomingo/postgresql-pig:18` from an unchanged commit
- **THEN** Renovate opens a PR that changes only umami's `postgresql-pig` digest, and merges it automatically

#### Scenario: Two own images rebuilt
- **WHEN** new builds are published for two own images used by different apps
- **THEN** Renovate opens two separate PRs, and neither update appears in the patch group PR

### Requirement: Renovate runs reliably on this repo
The self-hosted Renovate job SHALL include this repo, run on a schedule, and run
the Renovate version pinned in git.

#### Scenario: Scheduled run
- **WHEN** the Renovate CronJob fires
- **THEN** it processes `kvdomingo/homelab-automation` using the image tag set in `renovate/values.yaml`
