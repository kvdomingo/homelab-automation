# cluster-alerting Specification

## Purpose

Notifies the operator promptly when something in the cluster is wrong,
including when the monitoring stack itself is down.

## Requirements

### Requirement: Alerts are delivered to Discord

Firing and resolved alerts SHALL be posted to a Discord channel. The webhook URL
SHALL come from Infisical.

#### Scenario: Node goes down

- **WHEN** a node stops reporting for longer than the rule's `for` duration
- **THEN** a firing alert appears in Discord, and a resolved message follows
  once the node recovers

### Requirement: Silence of the alerting pipeline is detected externally

The always-firing `Watchdog` alert SHALL be sent to an external dead man's
switch outside the cluster, which notifies the operator when the heartbeat
stops.

#### Scenario: Alertmanager or the cluster is down

- **WHEN** no `Watchdog` heartbeat reaches the dead man's switch for its period
  plus grace time
- **THEN** the operator is notified by the dead man's switch, independent of the
  cluster

#### Scenario: Watchdog does not reach Discord

- **WHEN** `Watchdog` is firing normally
- **THEN** it is not posted to Discord

### Requirement: Default alerts are quiet on a healthy cluster

On a healthy cluster, only `Watchdog` (and `InfoInhibitor`, if present) SHALL
be firing. Rules that cannot apply to k3s SHALL be disabled, not left firing.

#### Scenario: Steady state

- **WHEN** all nodes and workloads are healthy for 30 minutes
- **THEN** the Alertmanager UI shows no firing alerts other than `Watchdog` and
  `InfoInhibitor`

### Requirement: Disk space is alerted on

Alerts SHALL fire before node root filesystems (shared by Longhorn and
containerd) or monitoring PVCs fill up.

#### Scenario: Prometheus volume filling

- **WHEN** a PVC is predicted to fill within the default rule's horizon
- **THEN** `KubePersistentVolumeFillingUp` fires to Discord
