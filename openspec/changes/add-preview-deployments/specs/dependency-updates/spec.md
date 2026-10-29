# Spec Delta

## MODIFIED Requirements

### Requirement: Versions are pinned in git

Every container image and Helm chart the repo deploys SHALL reference a concrete
version. Floating tags (`latest`, `stable`, `latest-<variant>`, a bare major
like `v3`) and untagged image references SHALL NOT be used. Charts that are
built from this repo itself (`targetRevision: main` / `HEAD` on the
`homelab-automation` repo or the user's own app repos) are exempt. Preview
environments are exempt from pinning their app image in git: each runs the
immutable commit tag of its pull request's head, supplied at deploy time.

#### Scenario: Floating tag rejected

- **WHEN** a manifest, values file, or `valuesObject` sets an image tag to
  `latest`, `stable`, or another non-version tag
- **THEN** the change does not meet this requirement and the tag MUST be
  replaced with a concrete version that upstream publishes

#### Scenario: Untagged image

- **WHEN** an `image:` string has no tag (e.g. `busybox`)
- **THEN** it MUST be given a concrete version tag

#### Scenario: Own image tagged by commit

- **WHEN** an image is under `ghcr.io/kvdomingo/` and its CI tags every build of
  the default branch with the short commit SHA
- **THEN** it MUST be pinned to that tag, e.g. `sha-cf6d19f`, not `latest`

#### Scenario: Own image rebuilt without a new commit

- **WHEN** an own image is rebuilt on a schedule from the same commit
  (`postgresql-pig`)
- **THEN** it MUST be pinned to its tag plus digest, e.g. `18@sha256:<digest>`

#### Scenario: Preview image

- **WHEN** a preview environment runs the build of PR head commit `abc1234`
- **THEN** it uses the tag `sha-abc1234`, never a mutable per-PR or branch tag

### Requirement: Version changes only come from git

The cluster SHALL NOT change a workload's image or chart version except through
a commit to `main` that ArgoCD (or a manual `helmfile apply`) deploys. No
workload SHALL carry `keel.sh/*` annotations. Preview environments are exempt:
their image follows their pull request's head commit, and they never serve
production traffic.

#### Scenario: New upstream image published

- **WHEN** upstream publishes a new version of an image a workload uses
- **THEN** the running workload keeps its current version until a commit
  changing that version is merged to `main`

#### Scenario: Keel still installed

- **WHEN** the Keel controller is running in the cluster
- **THEN** it updates no workload, because no workload opts in through
  annotations

#### Scenario: Push to a previewed PR

- **WHEN** a commit is pushed to an open primerdriver PR
- **THEN** only that PR's preview changes version; production primerdriver keeps
  the version pinned on `main`
