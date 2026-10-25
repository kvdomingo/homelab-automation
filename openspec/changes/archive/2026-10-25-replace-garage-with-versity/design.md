# Design

## Context

- Garage holds one bucket (`test`) with one key (`zephyr3-wsl`). No workload in
  the repo or cluster references it.
- TrueNAS CE at `10.10.10.100` already runs custom apps (Jellyfin, Prowlarr,
  Sonarr) configured in its UI. Pool `big-chonk` has about 4TB free.
- New workloads get secrets from Infisical (`infisical-secrets/<app>/`).

## Goals / Non-Goals

**Goals:**

- One S3 endpoint that writes straight to ZFS.
- Garage fully removed from git and the cluster.

**Non-Goals:**

- GitOps for TrueNAS apps. The app is configured by hand.
- TLS, a DNS hostname, per-consumer IAM users. Add when a consumer needs them.
- Creating the `thanos` and `loki` buckets; `add-cluster-observability` does
  that.
- Removing MinIO. nocodb, n8n, plane and lakefs still use it; a later change
  moves them.

## Decisions

- **Versity Gateway, `posix` backend, on the NAS.** Objects are plain files and
  metadata goes in ZFS xattrs, so there is no metadata database to run or
  corrupt. Alternatives: single-node Garage (keeps a metadata DB), SeaweedFS
  (four components), pgsty/minio (single-maintainer fork), Versity in-cluster
  (needs xattrs over NFSv4.2, unverified).
- **Dedicated dataset `big-chonk/s3`.** Gives S3 data its own snapshot and
  quota policy, separate from `k8s-nfs-prod`. Set `xattr=sa` for performance.
- **Root credentials only.** Versity's root access/secret key are set as app
  env vars in the TrueNAS UI, kept in Vaultwarden, and copied into each
  consumer's Infisical project.
- **Plain HTTP by IP.** SigV4 never sends the secret key; LAN-only exposure.
- **Port.** Versity's default `7070` unless it collides with an existing
  TrueNAS app.

## Risks / Trade-offs

- [App config lives only in the TrueNAS UI] → AGENTS.md records it; the app
  takes three settings (image tag, root keys, dataset mount).
- [Image tag not tracked by Renovate] → bump it in the TrueNAS UI alongside the
  other NAS apps.
- [Removing Garage deletes the `test` bucket] → it is a test bucket; confirm
  with the user before deleting PVCs.

## Migration Plan

1. Create dataset and Versity app on TrueNAS; verify with an S3 client.
2. Store credentials in Vaultwarden.
3. Remove Garage from git; ArgoCD prunes it. Delete leftover PVCs if the
   finalizer leaves them.
4. Rollback: revert the commit; ArgoCD recreates Garage (empty).
