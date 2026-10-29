# Spec Delta

## Purpose

Defines how GitHub events reach ArgoCD so that deployments and preview
environments react to pushes and pull requests without waiting for a poll.

## ADDED Requirements

### Requirement: Pushes to the GitOps repo trigger an ArgoCD refresh

GitHub SHALL deliver `push` events from `kvdomingo/homelab-automation` to
`https://argo.kvd.studio/api/webhook`. ArgoCD SHALL refresh the Applications
that track the pushed branch on receipt.

#### Scenario: Push to main

- **WHEN** a commit is pushed to `main` of `homelab-automation`
- **THEN** GitHub records a delivery to `argo.kvd.studio/api/webhook` with
  response 200
- **AND** affected Applications start syncing the new revision within 30
  seconds, without waiting for `timeout.reconciliation`

### Requirement: Pull request events trigger the preview generator

GitHub SHALL deliver `pull_request` events from `kvdomingo/primerdriver` to
`https://argo.kvd.studio/api/webhook/appset`. The ApplicationSet controller
SHALL re-run the `primerdriver-previews` generator on receipt.

#### Scenario: Pull request opened

- **WHEN** a pull request is opened on `primerdriver`
- **THEN** the `primerdriver-pr-<n>` Application exists within 30 seconds

#### Scenario: Pull request closed

- **WHEN** a pull request on `primerdriver` is closed or merged
- **THEN** the `primerdriver-pr-<n>` Application is deleted within 30 seconds

### Requirement: Webhook deliveries are authenticated

Both webhook endpoints SHALL accept only payloads signed with the shared
GitHub webhook secret. The secret SHALL come from Infisical and SHALL NOT be
committed to git.

#### Scenario: Unsigned payload

- **WHEN** a request without a valid `X-Hub-Signature-256` is posted to
  either webhook endpoint
- **THEN** ArgoCD does not refresh any Application or ApplicationSet

#### Scenario: Secret rotation

- **WHEN** `GITHUB_WEBHOOK_SECRET` changes in Infisical and in both GitHub
  webhooks
- **THEN** new deliveries succeed without a commit to this repo

### Requirement: Webhook endpoints accept only GitHub source IPs

Cloudflare SHALL block requests to paths under `/api/webhook` on
`argo.kvd.studio` unless the source IP is in GitHub's published hook ranges.
Other paths on that host SHALL NOT be affected.

#### Scenario: Request from a non-GitHub IP

- **WHEN** a client outside GitHub's hook ranges posts to either webhook
  endpoint
- **THEN** Cloudflare answers 403 and the request does not reach the cluster

#### Scenario: GitHub delivery

- **WHEN** GitHub delivers a webhook to either endpoint
- **THEN** the request reaches ArgoCD, which then checks the signature

#### Scenario: ArgoCD UI unaffected

- **WHEN** a client outside GitHub's ranges opens `https://argo.kvd.studio/`
- **THEN** the WAF rule does not block it

### Requirement: Polling remains as a fallback

ArgoCD SHALL keep polling Git and the GitHub pull request API, so a missed
delivery delays a change instead of dropping it.

#### Scenario: Delivery lost

- **WHEN** a webhook delivery fails
- **THEN** the change is still picked up by the next poll (at most 3 minutes
  for Applications, 10 minutes for previews)
