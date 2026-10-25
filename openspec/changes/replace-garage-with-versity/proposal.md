# Proposal

## Why

Garage runs as 4 in-cluster replicas with `replicationFactor: 3`, but every
replica's data and LMDB metadata PVC sits on the same `nfs-client` share on the
TrueNAS box. That triples every write, gives no real redundancy (ZFS already
provides it), and puts Garage's metadata on NFS, which Garage warns against.
The upcoming cluster observability work (Thanos, Loki) needs an S3 endpoint it
can rely on for months of history, so the object store should be fixed first.

## What Changes

- Add a single S3 endpoint, Versity Gateway (`posix` backend), running as a
  TrueNAS CE custom app on `10.10.10.100`, writing to a dedicated ZFS dataset.
  Set up by hand in the TrueNAS UI; it is not GitOps-managed.
- Clients reach it by IP (`http://10.10.10.100:<port>`) with path-style
  addressing. No Traefik hostname.
- **BREAKING**: remove Garage (`apps/apps/templates/garage.yaml`, `garage/`,
  its namespace and PVCs). It holds only a `test` bucket and has no in-cluster
  consumers, so nothing is migrated.
- Document in `AGENTS.md` that the S3 endpoint is managed manually on TrueNAS.

## Capabilities

### New Capabilities

- `object-storage`: where the homelab's S3-compatible storage lives, how
  clients address it, and how its credentials reach workloads.

### Modified Capabilities

None.

## Impact

- Removed: `apps/apps/templates/garage.yaml`, `garage/secret.yaml`, the
  `garage` namespace, its 8 `nfs-client` PVCs, and the `garage` Infisical
  project (after removal).
- Added (outside git): TrueNAS dataset and custom app for Versity Gateway.
- `AGENTS.md`: deploy notes.
- Unblocks `add-cluster-observability`, which stores Thanos blocks and Loki
  chunks on this endpoint.
