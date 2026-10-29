# Spec Delta

## Purpose

Gives every open pull request on an app repo its own running copy of the app, so
changes can be tried before merging and a broken build can block an automated
merge.

## ADDED Requirements

### Requirement: Every open pull request gets a preview

Each open pull request on `kvdomingo/primerdriver` SHALL have its own preview
environment, created without human action within 5 minutes of the PR's image
being published. Pull requests from Renovate SHALL be included.

#### Scenario: PR opened

- **WHEN** a pull request is opened on `kvdomingo/primerdriver` and CI publishes
  its image
- **THEN** a preview environment for that PR is running within 5 minutes

#### Scenario: Renovate PR

- **WHEN** Renovate opens a dependency PR on `kvdomingo/primerdriver`
- **THEN** it gets a preview environment like any other PR

### Requirement: A preview runs the PR's latest commit

A preview SHALL run the image built from its PR's current head commit. A new
push to the PR SHALL replace the preview's build with the new head's build.

#### Scenario: New commit pushed

- **WHEN** a commit is pushed to an open PR and CI publishes its image
- **THEN** the preview switches to that commit's build

### Requirement: Previews have a predictable internal address

The preview for PR number `<n>` SHALL be served at
`https://primerdriver-pr-<n>.lab.kvd.studio` with a valid certificate. Previews
SHALL NOT be reachable from outside the home network and SHALL NOT appear on the
Homepage dashboard.

#### Scenario: Opening a preview

- **WHEN** a user on the home network opens `https://primerdriver-pr-42.lab.kvd.studio`
- **THEN** they reach PR #42's build over valid TLS

#### Scenario: External access

- **WHEN** someone outside the home network requests a preview host
- **THEN** the request does not reach the preview

### Requirement: Previews are isolated from production

A preview SHALL NOT receive production traffic, and creating, updating, or
deleting a preview SHALL NOT change the production workload.

#### Scenario: Preview fails

- **WHEN** a preview's build crash-loops
- **THEN** `primerdriver.kvd.studio` keeps serving production unaffected

### Requirement: Previews are removed when the PR closes

When a pull request is merged or closed, its preview SHALL be deleted within 5
minutes, leaving no workload, service, or ingress behind.

#### Scenario: PR merged

- **WHEN** PR #42 is merged
- **THEN** within 5 minutes `primerdriver-pr-42.lab.kvd.studio` stops resolving
  to a backend and none of the preview's resources remain in the cluster

### Requirement: Previews report their result to the PR

Each preview SHALL post a commit status with context `preview/primerdriver` on
the PR's head commit: `pending` while the build is deploying, `success` once it
is healthy, and `failure` if it fails to become healthy. The success status
SHALL link to the preview's URL.

#### Scenario: Healthy preview

- **WHEN** the preview for head commit `abc1234` becomes healthy
- **THEN** commit `abc1234` gets a `success` status `preview/primerdriver`
  linking to the preview URL

#### Scenario: Broken build

- **WHEN** the preview's build fails to become healthy
- **THEN** the head commit gets a `failure` status `preview/primerdriver`

#### Scenario: Status belongs to the new commit

- **WHEN** a new commit is pushed while the previous commit's preview is healthy
- **THEN** the new commit does not get `success` until its own build is healthy

### Requirement: A passing preview is required to merge

`kvdomingo/primerdriver` `main` SHALL require a `success` status for
`preview/primerdriver` before a pull request can be merged.

#### Scenario: Merge before preview finishes

- **WHEN** a PR's preview status is missing or `pending`
- **THEN** GitHub does not allow the PR to be merged

### Requirement: Renovate dependency PRs merge only after a passing preview

Self-hosted Renovate SHALL process `kvdomingo/primerdriver`. Its non-major
dependency PRs there SHALL be merged without human action once all required
checks, including `preview/primerdriver`, pass, and SHALL stay open while any
fails.

#### Scenario: Dependency bump keeps the app healthy

- **WHEN** Renovate opens a minor dependency PR on `kvdomingo/primerdriver` and
  its preview reports `success`
- **THEN** Renovate merges the PR

#### Scenario: Dependency bump breaks the app

- **WHEN** a Renovate PR's preview reports `failure`
- **THEN** the PR stays open and unmerged
