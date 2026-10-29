# Spec Delta

## Purpose

Defines how a production workload moves to a new build without downtime: the new
build takes traffic only after proving healthy, and a bad build never replaces a
good one.

## ADDED Requirements

### Requirement: New builds start beside the current one

When an opted-in workload's version changes, the new build SHALL start alongside
the running version while the running version keeps serving all production
traffic. Opted-in workloads are primerdriver's production deployment.

#### Scenario: Tag bump merged

- **WHEN** a commit changing primerdriver's image tag reaches `main` and ArgoCD
  syncs it
- **THEN** pods of the new build start while `primerdriver.lab.kvd.studio` and
  `primerdriver.kvd.studio` keep serving the previous build

### Requirement: Traffic switches only to a healthy build

Production traffic SHALL switch to the new build automatically, without human
action, only after every new pod has passed its health check
(`GET /api/health`) continuously for at least 30 seconds. The switch SHALL move
all traffic at once.

#### Scenario: Healthy build

- **WHEN** the new pods answer `/api/health` successfully for 30 seconds
- **THEN** all production traffic moves to the new build with no request served
  by a missing backend

#### Scenario: Build fails shortly after start

- **WHEN** a new pod passes its health check once and then crashes within 30
  seconds
- **THEN** traffic stays on the previous build

### Requirement: Unhealthy builds are abandoned

A new build that is not healthy within 5 minutes SHALL be aborted: production
SHALL stay on the previous build, and ArgoCD SHALL show the application as
Degraded.

#### Scenario: Build never becomes healthy

- **WHEN** the new pods crash-loop or fail their health check for 5 minutes
- **THEN** the rollout aborts, production traffic never reaches the new build,
  and the ArgoCD application reports Degraded

### Requirement: The previous build stays warm for rollback

After a switch, the previous build SHALL keep running for 10 minutes. Reverting
the version commit within that window SHALL move traffic back without waiting
for new pods to start.

#### Scenario: Revert within the window

- **WHEN** the commit that bumped the tag is reverted on `main` within 10
  minutes of the switch
- **THEN** traffic returns to the still-running previous pods as soon as ArgoCD
  syncs

#### Scenario: Window elapsed

- **WHEN** 10 minutes have passed since the switch
- **THEN** the previous build's pods are scaled down
