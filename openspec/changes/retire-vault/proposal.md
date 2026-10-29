# Proposal

## Why

Every workload already gets its secrets from Infisical, yet HashiCorp Vault
still runs in the cluster and ArgoCD still renders eleven apps through
`argocd-vault-plugin-helm`. The plugin no longer substitutes anything: it is a
pass-through that adds two repo-server sidecars, an init container that curls
unpinned binaries, and a Vault token kept in a gitignored, hand-applied
`argocd/manifests/secrets.yaml`. Removing Vault leaves one secrets system.

## What Changes

- Move the eleven `argocd-vault-plugin-helm` Applications to native ArgoCD
  sources: `path:` only for plain charts, `helm.valuesObject` for the two
  that pass `HELM_VALUES` (`delphitools`, `home-assistant`).
- Remove the AVP config management plugins from ArgoCD: the `avp` and
  `avp-helm` sidecars, the `download-tools` init container, the `cmp-plugin`
  and `custom-tools` volumes, and the `manifests` helmfile release
  (`cmp-plugin` ConfigMap and `vault-configuration` Secret). This includes
  deleting the gitignored local `argocd/manifests/secrets.yaml`.
- **BREAKING** Remove the `vault` Application from `core/apps/` and tear down
  the `vault` namespace, including its data PVC. Secrets held only in Vault
  are lost.
- Delete the orphaned `plausible/` chart. No Application references it, and
  its only secret template is an AVP placeholder.
- Update `AGENTS.md`: Infisical is the only secrets mechanism.
- Keep `secrets-store-csi-driver`. Its token request is for the `infisical`
  audience, not Vault.

Non-goal: changing how apps use Infisical.

## Capabilities

### New Capabilities

- `secrets-management`: how cluster workloads get secrets, which is
  Infisical only, and the absence of Vault and secret-substituting ArgoCD
  plugins.

### Modified Capabilities

None.

## Impact

- `apps/apps/templates/`: `atuin`, `apod`, `banyuhay`, `delphitools`,
  `discai`, `excalidraw`, `hd2-app`, `home-assistant`, `it-tools`, `n8n`,
  `primerdriver`.
- `core/apps/templates/vault.yaml` (deleted).
- `argocd/values.yaml`, `argocd/helmfile.yaml`, `argocd/manifests/`
  (deleted). Needs a manual `helmfile apply` in `argocd/`.
- `plausible/` (deleted), `AGENTS.md`.
- Cluster: `vault` namespace and PVC, plus the `argocd` `cmp-plugin` and
  `vault-configuration` objects, which helmfile does not prune once their
  release is gone.
