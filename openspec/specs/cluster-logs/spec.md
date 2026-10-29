# cluster-logs Specification

## Purpose

Collects pod logs and Kubernetes events from every node and keeps them
searchable in Grafana for 30 days.

## Requirements

### Requirement: Pod logs are collected from every node

Container logs from every pod on every node, amd64 and arm64, SHALL be shipped
to the log store, labelled with at least namespace, pod, container and node.

#### Scenario: Pod writes to stdout

- **WHEN** a pod in any namespace writes a line to stdout or stderr
- **THEN** the line is queryable in Grafana by namespace and pod within one
  minute

### Requirement: Kubernetes events are collected

Kubernetes events SHALL be stored in the log store alongside pod logs.

#### Scenario: Pod is OOM-killed

- **WHEN** the API server records an event for a workload (e.g. `OOMKilled`,
  `FailedScheduling`)
- **THEN** the event is queryable in Grafana

### Requirement: Logs are kept for 30 days on object storage

Logs SHALL be stored on the S3 endpoint and deleted after 30 days.

#### Scenario: Log older than 30 days

- **WHEN** a log line is older than 30 days
- **THEN** it is no longer returned and its chunks are deleted from the bucket
