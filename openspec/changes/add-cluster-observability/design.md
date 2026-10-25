# Design

## Context

- 7 k3s nodes: `srv-k8s-01..03` (amd64, ~16GB, 54-70% memory used) and
  `srv-pi5-01..04` (arm64, 8GB). Control plane: `srv-k8s-01..03` and
  `srv-pi5-01`. The inventory lists `srv-pi5-01` under `k8s_agents` although it
  runs as a server.
- k3s installs with `--disable=traefik,coredns,metrics-server` passed as CLI
  args in four ansible roles. No `/etc/rancher/k3s/config.yaml.d/` drop-ins.
- Longhorn has no volumes yet. Schedulable space per replica (after its 25%
  reserve) is roughly 98G on pi5-01, 20G on pi5-02/03, 12G on k8s-01, and
  5-6G elsewhere. Default replica count is 3.
- 10 `monitoring.coreos.com` CRDs remain from the abandoned install.
- cert-manager is installed (`core/apps/templates/certmanager.yaml`).
- The S3 endpoint is Versity at `http://10.10.10.100:<port>` (see
  `replace-garage-with-versity`).

## Goals / Non-Goals

**Goals:** see specs `cluster-metrics`, `cluster-logs`, `cluster-alerting`.

**Non-Goals:**
- Traces (Tempo), Mimir, Loki-based alert rules.
- Thanos/Loki/Alloy dashboards beyond what charts ship by default.
- Ingress for Prometheus, Alertmanager or Thanos Query. Grafana covers querying
  and Alertmanager silences.

## Decisions

### Layout

```
core/apps/templates/
  promstack.yaml   kube-prometheus-stack + infisical-secrets/monitoring
  thanos.yaml      stevehipwell/thanos (query, storegateway, compactor)
  loki.yaml        grafana/loki (SingleBinary)
  alloy.yaml       grafana/alloy x2: alloy-logs (DaemonSet), alloy-events (Deployment, 1 replica)
infisical-secrets/monitoring/secret.yaml
ansible/expose-k3s-metrics.yml
```

All in namespace `monitoring`, project `core-prod`, Helm-repo sources in
`repoURL` / `chart` / `targetRevision` order so Renovate's existing
"Application Helm-repo chart" manager tracks them. No new Renovate config.

- **ArgoCD, not helmfile.** Everything else in `core/` is ArgoCD-managed;
  helmfile was a manual step that drifted. `promstack.yaml` uses
  `ServerSideApply=true`: the kube-prometheus-stack CRDs exceed the
  client-side annotation limit. SSA also adopts the leftover CRDs.
- **Operator webhook certs from cert-manager**
  (`prometheusOperator.admissionWebhooks.certManager.enabled: true`). The
  default patch-job flow rewrites `caBundle` on every sync, which keeps the app
  OutOfSync under ArgoCD.

### Secrets

One Infisical project `monitoring` → `InfisicalSecret` → `monitoring-secrets`
in `monitoring`. Keys: `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`,
`DISCORD_WEBHOOK_URL`, `HEALTHCHECKS_PING_URL`, `S3_ACCESS_KEY_ID`,
`S3_SECRET_ACCESS_KEY`.

- Thanos needs an `objstore.yml` file, not env vars. The `InfisicalSecret`
  template renders it from the two S3 keys into an `objstore.yml` key, so the
  keys are stored once. Alternative: store the whole YAML as one Infisical
  value (duplicates the keys).
- Loki reads the keys as env vars (`extraEnvFrom` + `-config.expand-env=true`).
- Alertmanager mounts the secret (`alertmanagerSpec.secrets`) and uses
  `webhook_url_file` / `url_file`, so URLs never appear in the rendered config.
- Grafana uses `admin.existingSecret`. Grafana, Loki and Alloy get
  `secrets.infisical.com/auto-reload: "true"`.

### Metrics

- Prometheus: 1 replica, `scrapeInterval: 30s`, `retention: 14d`,
  `retentionSize: 8GB`, Longhorn PVC 10Gi.
  `*SelectorNilUsesHelmValues: false` so it picks up monitors in all namespaces.
- Thanos sidecar via `prometheusSpec.thanos.objectStorageConfig.existingSecret`
  and `prometheus.thanosService.enabled: true`. The operator turns off local
  compaction when this is set.
- Thanos chart: Query (store endpoints: sidecar gRPC service and the Store
  Gateway), Store Gateway, Compactor with `--downsampling` and
  `--retention.resolution-raw=30d`, `-5m=180d`, `-1h=365d`. Everything else
  in the chart is disabled. Store Gateway and Compactor scratch go on
  `nfs-client` PVCs (cache/working space only; data is rebuilt from the bucket).
- Single Prometheus means no replica labels and no dedup config in Query.
- Grafana's default datasource points at Thanos Query
  (`grafana.sidecar.datasources.url`), so one datasource covers recent and old
  data.

### k3s control-plane metrics

k3s runs etcd, scheduler, controller-manager and kube-proxy inside one process,
bound to `127.0.0.1`. `ansible/expose-k3s-metrics.yml` writes
`/etc/rancher/k3s/config.yaml.d/90-metrics.yaml` and restarts k3s one node at a
time (`serial: 1`):

- all nodes: `kube-proxy-arg: [metrics-bind-address=0.0.0.0:10249]`
- control-plane nodes: plus `etcd-expose-metrics: true`,
  `kube-controller-manager-arg: [bind-address=0.0.0.0]`,
  `kube-scheduler-arg: [bind-address=0.0.0.0]`

Control-plane hosts come from a new inventory group `k8s_control_plane`
(`srv-k8s-01..03`, `srv-pi5-01`), so existing groups and the playbooks that use
them are unchanged. A drop-in instead of new CLI args keeps the four install
roles untouched and survives `upgrade-k8s.yml`.

kube-prometheus-stack values list the control-plane IPs as `endpoints` for
`kubeEtcd` (2381, http), `kubeControllerManager` (10257, https, skip verify),
`kubeScheduler` (10259, https, skip verify); `kubeProxy` uses pod discovery on
10249.

### Logs

- Loki chart, `deploymentMode: SingleBinary`, 1 replica, Longhorn PVC 5Gi (WAL,
  index cache, compactor working dir). Schema v13 / tsdb. Storage: S3 bucket
  `loki` for chunks and ruler, `s3forcepathstyle: true`, `insecure: true`.
  Retention: `limits_config.retention_period: 720h`, compactor
  `retention_enabled: true`, `delete_request_store: s3`.
- Disabled: gateway, chunks/results memcached, canary, helm tests, bundled
  MinIO, and the read/write/backend targets. Memcached alone would take several
  GB of memory at default size.
- Alloy, two releases of the same chart:
  - `alloy-logs`, DaemonSet: discovers pods on its own node, tails
    `/var/log/pods` (`hostPath`), adds namespace/pod/container/node labels.
    Reading files avoids streaming every log through the API server.
  - `alloy-events`, Deployment with 1 replica: `loki.source.kubernetes_events`.
    In the DaemonSet it would ship every event once per node.

### Alerting

Alertmanager route:

- `alertname=Watchdog` → `healthchecks` (webhook to the healthchecks.io ping
  URL, `repeat_interval: 1m`). The healthchecks.io check (period 5m, grace 5m)
  notifies through its own Discord integration, so the notification does not
  depend on the cluster.
- `alertname=InfoInhibitor` → `null`.
- everything else → `discord`, `send_resolved: true`.

One extra `PrometheusRule` covers silent object-storage failures that no
default rule catches:
- `ThanosSidecarUploadFailing`: `increase(thanos_objstore_bucket_operation_failures_total{job=~".*prometheus.*"}[15m]) > 0` for 15m
- `ThanosCompactHalted`: `thanos_compact_halted == 1` for 5m

Any default rule still firing after a 24h soak on a healthy cluster is
disabled by name under `defaultRules.disabled`, with the reason in the commit
message.

### Retiring promstack

Delete `promstack/`, the `promstack` task in `Taskfile.yml`, and `promstack/`
from the helmfile lists in `AGENTS.md`.

## Risks / Trade-offs

- [k3s exposes one shared metrics registry, so each control-plane port can
  return all components' metrics, giving duplicate series] → check after
  rollout; if duplicated, add `metricRelabelings` keeping only each
  component's prefix (`etcd_`, `scheduler_`, `workqueue_`, `kubeproxy_`, ...).
- [Longhorn space: about 16Gi per replica set (10 + 5 + 1) across 3 nodes,
  close to the 20G available on pi5-02/03] → `NodeFilesystemAlmostOutOfSpace`
  and `KubePersistentVolumeFillingUp` alert first; Loki's PVC can drop to 3Gi.
- [Restarting k3s on control-plane nodes] → `serial: 1` and wait for the node
  to be Ready before the next; etcd keeps quorum with 3 of 4 up.
- [Versity down] → the sidecar retries uploads and Prometheus keeps 14d
  locally; Loki buffers in its WAL; `ThanosSidecarUploadFailing` fires.
- [Memory on 8GB Pis] → set requests so the scheduler places Prometheus and
  Loki where memory is free; leave limits off Prometheus to avoid OOM loops
  during compaction.
- [One Discord channel for everything] → acceptable now; per-severity routing
  can come later.

## Migration Plan

1. Run `expose-k3s-metrics.yml`; check the ports answer on each node.
2. Create the Infisical project, healthchecks.io check, and Versity buckets.
3. Merge the ArgoCD apps. Sync order doesn't matter: Thanos Query and Grafana
   retry until their backends exist.
4. Soak 24h; disable default rules that don't fit k3s.
5. Remove `promstack/`.

Rollback: revert the commit; ArgoCD prunes the apps. Leave the drop-in in
place; it only widens bind addresses on the LAN.
