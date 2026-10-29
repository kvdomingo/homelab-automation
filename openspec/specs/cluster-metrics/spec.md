# cluster-metrics Specification

## Purpose

Collects metrics from every node, the k3s control plane and workloads, keeps
them queryable for a year, and makes them visible in Grafana.

## Requirements

### Requirement: Metrics are scraped cluster-wide

Prometheus SHALL scrape every node, kube-state-metrics, and every
ServiceMonitor or PodMonitor in any namespace, at a 30s interval.

#### Scenario: Workload adds a ServiceMonitor

- **WHEN** a ServiceMonitor is created in any namespace
- **THEN** its targets appear in Prometheus without changing Prometheus config

#### Scenario: New node joins

- **WHEN** a node joins the cluster
- **THEN** its node-exporter target is up within one scrape interval of the pod
  starting

### Requirement: k3s control-plane targets are healthy

The etcd, scheduler, controller-manager and kube-proxy targets SHALL be
reachable and up on every node that runs them, so their default alerts only
fire on real failures.

#### Scenario: Healthy cluster

- **WHEN** all nodes are Ready
- **THEN** no `TargetDown`, `KubeSchedulerDown`, `KubeControllerManagerDown`,
  `KubeProxyDown` or etcd alerts are firing

### Requirement: Local retention is bounded

Prometheus SHALL keep at most 14 days or 8GB of local data, whichever limit is
reached first, on a Longhorn volume that survives pod rescheduling.

#### Scenario: Pod rescheduled

- **WHEN** the Prometheus pod moves to another node
- **THEN** local data from before the move is still queryable

### Requirement: Long-term metrics are kept on object storage

Metric blocks SHALL be uploaded to the S3 endpoint and kept at raw resolution
for 30 days, 5-minute resolution for 6 months, and 1-hour resolution for 1 year.

#### Scenario: Query older than local retention

- **WHEN** Grafana queries a range older than Prometheus's local data
- **THEN** results come from object storage

#### Scenario: Data past retention

- **WHEN** a block is older than its resolution's retention
- **THEN** it is deleted from the bucket

### Requirement: Grafana is stateless and git-defined

Grafana SHALL keep no persistent volume. Its datasources (long-term metrics,
logs, Alertmanager) and dashboards SHALL come from git, and its admin
credentials from Infisical. It SHALL be reachable at `grafana.lab.kvd.studio`
and listed on Homepage.

#### Scenario: Grafana pod restarts

- **WHEN** the Grafana pod is deleted
- **THEN** the new pod has the same datasources and dashboards, and the admin
  login still works
