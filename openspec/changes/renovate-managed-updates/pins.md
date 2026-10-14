# Pinned versions

Floating or untagged references replaced in this change, with the version chosen
under design D5. "Running" means a registry tag with the same digest as the
running pod's `imageID` on 2026-10-14.

| File | Image | Was | Now | Basis |
| --- | --- | --- | --- | --- |
| `actual-budget/values.yaml` | `actualbudget/actual-server` | `latest` | `26.10.0` | running |
| `atuin/values.yaml` | `ghcr.io/atuinsh/atuin` | `latest` | `v18.12.0` | running |
| `bytebase/values.yaml` | `bytebase/bytebase` | `latest` | `3.23.1` | running |
| `excalidraw/values.yaml` | `ghcr.io/kvdomingo/excalidraw` | `latest` | `sha-74470e7` | running, branch head |
| `ihatemoney/values.yaml` | `ihatemoney/ihatemoney` | `latest` | `7.2.1` | running |
| `it-tools/values.yaml` | `corentinth/it-tools` | `latest` | `2024.10.22-7ca5933` | running |
| `lubelogger/values.yaml` | `ghcr.io/hargata/lubelogger` | `latest` | `v1.7.3` | running |
| `n8n/values.yaml` | `docker.n8n.io/n8nio/n8n` | `latest` | `2.43.5` | running |
| `n8n/values.yaml` | `bitnami/os-shell` (redis subchart) | chart default `latest` | `latest@sha256:85cd5365…` | running digest; no version tags |
| `nocodb/values.yaml` | `nocodb/nocodb` | `latest` | `2026.09.1` | running |
| `nocodb/values.yaml` | `bitnami/os-shell` (redis subchart) | chart default `latest` | `latest@sha256:85cd5365…` | running digest; no version tags |
| `pgadmin/values.yaml` | `dpage/pgadmin4` | `9` | `9.18.0` | running |
| `primerdriver/values.yaml` | `ghcr.io/kvdomingo/primerdriver` | `latest` | `sha-c87a38b` | newest: the running build (commit `4989d33`) has no `sha-` tag |
| `solidinvoice/values.yaml` | `solidinvoice/solidinvoice` | `3` | `3.0.1` | running |
| `solidtime/values.yaml` | `solidtime/solidtime` | `latest` | `0.21.0` | running (one pod was on `0.20.1`) |
| `solidtime/values.yaml` | `gotenberg/gotenberg` | `8` | `8.27.0` | running |
| `tandoor/values.yaml` | `vabene1111/recipes` | `latest` | `2.6.15` | running |
| `umami/values.yaml` | `umami-software/umami` | `3` | `3.0.3` | running |
| `umami/values.yaml` | `bitnami/os-shell` (redis subchart) | chart default `latest` | `latest@sha256:abeb5b68…` | running digest; no version tags |
| `umami/templates/deployment.yaml` | `ghcr.io/kvdomingo/postgresql-pig` | `18` | `18@sha256:8963a69b…` | running (`18` has since moved) |
| `wallos/values.yaml` | `bellamy/wallos` | `latest` | `5.8.3` | running |
| `*/templates/tests/test-connection.yaml` (25 charts) | `busybox` | untagged | `1.37.0` | newest stable; Helm test hooks don't run under ArgoCD |
| `renovate/values.yaml` | `renovate/renovate` | `43`, ignored (ran `latest`) | `44.157.0` | running |
| `core/apps/templates/keel.yaml` | `ghcr.io/keel-hq/keel` | `latest` | `0.22.3` | running |
| `apps/apps/templates/cloudflare.yaml` | `cloudflare/cloudflared` | `latest` | `2026.10.0` | running |
| `apps/apps/templates/dagster.yaml` | `dagster/dagster-celery-k8s` (×2) | `latest` | `1.13.26` | running |
| `apps/apps/templates/dagster.yaml` | `library/postgres` | `18` | `18.6` | newest: running digests match no `18.x` tag |
| `apps/apps/templates/dagster.yaml` | `bitnami/minideb` | `stretch` | `stretch@sha256:a6f24bce…` | current digest; rabbitmq is disabled |
| `apps/apps/templates/delphitools.yaml` | `ghcr.io/kvdomingo/delphitools` | `latest` | `sha-097f270` | newer of two running pods, branch head |
| `apps/apps/templates/firefly.yaml` | `fireflyiii/core` | `version-6` | `version-6.5.1` | newer of two running pods (other: `6.2.12`) |
| `apps/apps/templates/home-assistant.yaml` | `ghcr.io/home-assistant/home-assistant` | `latest` | `2026.7.4` | running |
| `apps/apps/templates/portainer.yaml` | `portainer/portainer-ce` | `latest` | `2.39.1` | running; disabled EE override removed |
| `apps/apps/templates/tailscale.yaml` | `tailscale/k8s-operator`, `tailscale/tailscale` | `stable` | chart default `v1.94.2` | running; override removed |
| `apps/apps/templates/vaultwarden.yaml` | `vaultwarden/server` | `latest-alpine` | `1.37.4-alpine` | running |
| `infisical/values.yaml` | `infisical/infisical` | `latest` | `v0.166.6` | running |
| `infisical/values.yaml` | Infisical CLI (auto-bootstrap, disabled) | `latest` | chart default `0.41.86` | override removed |
| `argocd/values.yaml` | `registry.access.redhat.com/ubi8` | untagged | `8.10-1772639305` | running |
| `bind9/docker-compose.yaml` | `traefik` | `v3` | `v3.7.14` | current `v3` digest |
