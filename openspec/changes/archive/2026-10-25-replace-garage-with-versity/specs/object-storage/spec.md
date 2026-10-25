# Spec Delta

## Purpose

Provides the homelab's S3-compatible object storage: a single endpoint on the
TrueNAS host that cluster workloads use for bulk data such as metrics blocks
and log chunks.

## ADDED Requirements

### Requirement: Single S3 endpoint on the NAS

The homelab SHALL serve S3-compatible storage from one endpoint on the TrueNAS
host (`10.10.10.100`) that writes directly to a local ZFS dataset. Garage
SHALL NOT be deployed in the cluster.

#### Scenario: Cluster has no Garage

- **WHEN** the ArgoCD app-of-apps in `apps/apps/` and `core/apps/` is rendered
- **THEN** it contains no Application for Garage

#### Scenario: Data lands on ZFS

- **WHEN** a client uploads an object to a bucket
- **THEN** the object is stored on the dedicated ZFS dataset on the TrueNAS
  host, not on an NFS-backed PVC

### Requirement: Clients use the IP and path-style addressing

Clients SHALL address the endpoint as `http://10.10.10.100:<port>` with
path-style bucket addressing. Virtual-host addressing and a DNS hostname SHALL
NOT be required.

#### Scenario: Path-style request succeeds

- **WHEN** a client with valid credentials lists
  `http://10.10.10.100:<port>/<bucket>`
- **THEN** the endpoint returns the bucket listing

#### Scenario: Client configured for virtual-host style

- **WHEN** a workload's S3 client is configured
- **THEN** its configuration forces path-style addressing

### Requirement: Credentials reach workloads through Infisical

S3 access and secret keys SHALL reach cluster workloads only through
`InfisicalSecret`-managed Kubernetes secrets. Keys SHALL NOT be committed to
git.

#### Scenario: Workload needs S3 access

- **WHEN** a workload is configured to use the endpoint
- **THEN** it reads the access and secret keys from an Infisical-managed secret
  in its namespace

### Requirement: Manual management is documented

`AGENTS.md` SHALL state that the S3 endpoint runs as a TrueNAS custom app
managed by hand in the TrueNAS UI, and give its address.

#### Scenario: Looking for the S3 deployment

- **WHEN** someone reads the Deploying section of `AGENTS.md`
- **THEN** it says the S3 endpoint is managed manually on TrueNAS at
  `10.10.10.100`
