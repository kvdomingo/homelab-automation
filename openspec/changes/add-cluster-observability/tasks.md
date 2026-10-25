# Tasks

## 1. Prerequisites (manual)

- [x] 1.1 Confirm `replace-garage-with-versity` group 1 is done; create buckets
      `thanos` and `loki` on Versity; verify
      `aws --endpoint-url http://10.10.10.100:<port> s3 ls` lists both
- [x] 1.2 Create a healthchecks.io check (period 5m, grace 5m) with a Discord
      integration; verify a manual `curl <ping-url>` turns it green
- [x] 1.3 Create Infisical project `monitoring` (env `prod`) with
      `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`, `DISCORD_WEBHOOK_URL`,
      `HEALTHCHECKS_PING_URL`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, and
      grant the cluster identity access; verify with
      `infisical secrets --env prod`
- [x] 1.4 Rejoin `srv-pi5-01` as a server:
      `kubectl drain srv-pi5-01 --ignore-daemonsets --delete-emptydir-data`;
      from `ansible/`,
      `ansible srv-pi5-01 -b -m command -a /usr/local/bin/k3s-agent-uninstall.sh`,
      `kubectl delete node srv-pi5-01`,
      `ansible srv-k8s-01 -b -m fetch -a "src=/var/lib/rancher/k3s/server/node-token dest=outputs/node-token flat=true"`,
      `infisical run -- ansible-playbook setup-k8s-servers.yml --limit srv-pi5-01`,
      `kubectl uncordon srv-pi5-01`; verify the node's `k3s.io/node-args`
      annotation starts with `server` and `kubectl get nodes` shows all Ready

## 2. k3s control-plane metrics

- [x] 2.1 Add inventory group `k8s_control_plane` (children `k8s_primary`,
      `k8s_servers`) to `ansible/inventory/hosts.ini`; verify
      `ansible -i inventory/hosts.ini k8s_control_plane --list-hosts` prints
      `srv-k8s-01..03` and `srv-pi5-01`
- [x] 2.2 Write `ansible/expose-k3s-metrics.yml` (drop-in
      `/etc/rancher/k3s/config.yaml.d/90-metrics.yaml`, `serial: 1`, restart
      k3s, wait for node Ready); verify `ansible-playbook --check` passes
- [x] 2.3 Run the playbook; verify from another host that
      `curl -s <node>:10249/metrics` answers on every node and
      `curl -s <cp>:2381/metrics` answers on each control-plane node, and
      `kubectl get nodes` shows all Ready

## 3. Secrets

- [x] 3.1 Add `infisical-secrets/monitoring/secret.yaml` (modeled on
      `infisical-secrets/litellm/`) producing `monitoring-secrets` in
      `monitoring`, with a template rendering `objstore.yml` (type S3, bucket
      `thanos`, endpoint `10.10.10.100:<port>`, `insecure: true`,
      `bucket_lookup_type: path`) from the S3 keys; verify
      `helm template`/`kubectl apply --dry-run=client` accepts it

## 4. kube-prometheus-stack

- [x] 4.1 Add `core/apps/templates/monitoring.yaml` (wrapped in
      `disableMonitoring`, sources: `infisical-secrets/monitoring` +
      `prometheus-community/kube-prometheus-stack` pinned,
      `ServerSideApply=true`, `CreateNamespace=true`) with the values from
      design.md: Prometheus (30s, 14d/8GB, Longhorn 10Gi, selectors open, Thanos
      sidecar + `thanosService`), Alertmanager (Longhorn 1Gi, secret mount,
      routes), Grafana (stateless, `admin.existingSecret`, datasource URL →
      Thanos Query, Loki datasource, ingress `grafana.lab.kvd.studio` with
      Homepage annotations, auto-reload annotation), cert-manager webhook certs,
      k3s control-plane endpoints; verify `helm template core/apps` renders it
      and `prek run --all-files` passes
- [x] 4.2 Add the `object-storage` `PrometheusRule`
      (`ThanosSidecarUploadFailing`, `ThanosCompactHalted`) via
      `additionalPrometheusRulesMap`; verify it appears in
      `kubectl get prometheusrule -n monitoring` after sync
- [ ] 4.3 After sync, verify: `monitoring` app Healthy/Synced; every target in
      Prometheus is up; Grafana login works with Infisical credentials; deleting
      the Grafana pod keeps datasources and dashboards
- [x] 4.4 Verify alert delivery: Discord receives a test alert
      (`amtool alert add` or a temporary rule) firing and resolved, and the
      healthchecks.io check stays green from `Watchdog`; `Watchdog` does not
      appear in Discord

## 5. Thanos

- [x] 5.1 Add a `stevehipwell/thanos` source (pinned) to the `monitoring` app
      with Query, Store Gateway and Compactor (downsampling on by default, raw
      30d / 5m 180d / 1h 365d, `nfs-client` scratch PVCs), objstore from
      `monitoring-secrets`; verify `helm template core/apps` renders it
- [ ] 5.2 After sync, verify Thanos Query's Stores page lists the sidecar and
      Store Gateway as healthy, and within 2-3h the `thanos` bucket contains
      uploaded blocks (`aws ... s3 ls s3://thanos/`)
- [ ] 5.3 Verify Grafana panels over a range older than 2h return data through
      Thanos Query

## 6. Logs

- [x] 6.1 Add a `grafana/loki` source (pinned) to the `monitoring` app
      (SingleBinary per design.md, Longhorn 5Gi, S3 via env, retention 720h,
      caches/gateway/canary/minio off, auto-reload annotation); verify
      `helm template core/apps` renders it
- [x] 6.2 Add two `grafana/alloy` sources to the `monitoring` app as
      releases: `alloy-logs` DaemonSet tailing `/var/log/pods` with
      namespace/pod/container/node labels, and `alloy-events` single-replica
      Deployment with `loki.source.kubernetes_events`; verify
      `helm template core/apps` renders both
- [x] 6.3 After sync, verify in Grafana Explore: logs from a pod on an amd64
      node and one on a Pi; a `kubectl run` failing pod's events appear once
      (not once per node); `aws ... s3 ls s3://loki/` shows chunks

## 7. Soak and cleanup

- [ ] 7.1 After 24h healthy, list firing alerts; fix or disable
      (`defaultRules.disabled`) each one other than `Watchdog`/`InfoInhibitor`;
      verify Alertmanager shows only those two
- [ ] 7.2 Check duplicate control-plane series
      (`count by (__name__)({job="kube-scheduler"})` vs
      `{job="kube-controller-manager"}`); if duplicated, add `metricRelabelings`
      per design.md and verify counts drop
- [ ] 7.3 Check Longhorn usage per node; verify no node is below its reserve and
      `NodeFilesystemAlmostOutOfSpace` isn't firing
- [ ] 7.4 Delete `promstack/` and the `promstack` task in `Taskfile.yml`; remove
      `promstack/` from both helmfile lists in `AGENTS.md`; verify
      `grep -rn promstack AGENTS.md Taskfile.yml` only matches the new ArgoCD
      app (if at all) and `prek run --all-files` passes
