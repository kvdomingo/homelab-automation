# Proposal

## Why

The cluster has no metrics, logs or alerting. `promstack/`
(kube-prometheus-stack via a manual `helmfile apply`) was installed once and
abandoned because it did not work properly; only its CRDs remain. Problems in
the cluster go unnoticed until something visibly breaks.

## What Changes

- Deploy kube-prometheus-stack through ArgoCD (`core/apps/`): Prometheus
  (30s scrape, Longhorn 10Gi, 14d / 8GB local retention), Alertmanager,
  Grafana, node-exporter, kube-state-metrics.
- Expose k3s's embedded control-plane metrics (etcd, scheduler,
  controller-manager, kube-proxy) so their default alerts reflect reality
  instead of firing forever.
- Add Thanos (sidecar + `stevehipwell/thanos` chart: Query, Store Gateway,
  Compactor) shipping blocks to the Versity S3 endpoint. Long-term retention:
  raw 30d, 5m for 6 months, 1h for 1 year.
- Add Loki (single binary, 30d retention) on Versity and Alloy (DaemonSet)
  shipping pod logs and Kubernetes events.
- Route alerts to Discord, and route the always-firing `Watchdog` alert to an
  external dead man's switch (healthchecks.io).
- Grafana is stateless: datasources and dashboards come from git, admin
  credentials from Infisical.
- **BREAKING**: remove `promstack/` (helmfile + 165K values dump) and its
  `Taskfile.yml` task; update `AGENTS.md`.

## Capabilities

### New Capabilities

- `cluster-metrics`: collection, local and long-term retention, and querying of
  cluster and workload metrics.
- `cluster-logs`: collection, retention and querying of pod logs and
  Kubernetes events.
- `cluster-alerting`: alert delivery, and detection of the alerting pipeline
  itself going down.

### Modified Capabilities

None. New charts follow the existing `dependency-updates` rules.

## Impact

- Added: `core/apps/templates/{promstack,thanos,loki,alloy}.yaml`,
  `infisical-secrets/monitoring/`, a k3s config drop-in in `ansible/`.
- Removed: `promstack/`, the `promstack` task in `Taskfile.yml`.
- Storage: about 16Gi per Longhorn replica (Prometheus 10Gi, Loki 5Gi,
  Alertmanager 1Gi, 3 replicas each); `thanos` and `loki` buckets on Versity.
- External: a healthchecks.io check; a Discord webhook.
- Depends on `replace-garage-with-versity` task group 1 (Versity running).
