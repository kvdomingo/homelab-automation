# Design

## Context

- Every secret consumer is already on Infisical. That covers the five local
  charts and the external `banyuhay`, `discai`, `apod`, `hd2-app` and
  `delphitools` charts (each ships an `InfisicalSecret`). No `<path:`
  placeholder or `avp.kubernetes.io` annotation remains, except in the
  orphaned `plausible/` chart.
- Eleven Applications still name `plugin: argocd-vault-plugin-helm`. The
  plugin runs `helm template $ARGOCD_APP_NAME -n $ARGOCD_APP_NAMESPACE`
  with `$HELM_VALUES` and pipes the output through AVP, which now changes
  nothing.
- The plugin is wired through `argocd/values.yaml` (two sidecars, an init
  container, two volumes) and the `manifests` helmfile release
  (`cmp-plugin` ConfigMap, `vault-configuration` Secret). Both are applied
  by hand with `helmfile apply`. `secrets.yaml` is gitignored, so it exists
  only in local checkouts.
- `core-prod` syncs with `prune: true` and the resources finalizer. Deleting
  `vault.yaml` therefore deletes the Vault Application and its resources,
  but not the StatefulSet PVC or the `CreateNamespace` namespace.

## Goals / Non-Goals

**Goals:** no Application fails to render at any point during the
migration, and Vault data is only destroyed after a deliberate last step.

**Non-Goals:** touching `secrets-store-csi-driver`.

## Decisions

### Native source with identical render inputs

Each Application drops `plugin:`. Plain charts keep only `path:`. The two
with `HELM_VALUES` move that YAML verbatim under `helm.valuesObject`,
keeping the inline renovate comments. ArgoCD's default release name is the
Application name and its namespace is the destination, which is what the
plugin passed to `helm template`. Resource names and labels therefore stay
the same and nothing is recreated. Native Helm also runs
`helm dependency build`, which replaces the plugin's `init`.

Alternative: keep a plain-Helm CMP. Rejected: it duplicates built-in
behavior and keeps the sidecars.

### Two pushes, apps before plugin

Removing the plugin while any Application still references it makes that
app fail with "plugin not found". So:

1. Push the Application rewrites. Wait until all eleven are Synced and
   Healthy on native sources.
2. Push the removal of `vault.yaml`, the AVP config in `argocd/`,
   `plausible/` and the doc update. Run `helmfile apply` in `argocd/`.

### Drop the `manifests` release outright

Removing a release from `helmfile.yaml` does not uninstall it. Run
`helm -n argocd uninstall manifests` once, in the same manual step as the
`helmfile apply` that is already required. This is simpler than a
two-commit `installed: false` round trip.

### Delete `plausible/` instead of porting it

No Application references it, so porting its secret to Infisical would be
work on dead code. If Plausible comes back, it gets a new chart through the
normal "Adding an app" flow.

## Risks / Trade-offs

- [A secret exists only in Vault] → Before step 2, list Vault's KV paths
  and confirm each has an Infisical counterpart or is unused. The PVC is
  kept until after this check.
- [Native render differs from the plugin render, e.g. a CRD or hook] → The
  step 1 diff in ArgoCD is reviewed per app before syncing. Rollback means
  reverting the commit; the plugin is still installed at that point.
- [Orphans left in the cluster] → Clean up by hand after step 2: the
  `vault` PVC and namespace, plus `cmp-plugin` and `vault-configuration`
  if `helm uninstall` misses them.

## Migration Plan

1. Rewrite the eleven Applications, push, and confirm all Synced and
   Healthy.
2. Audit Vault KV against Infisical (manual, read-only).
3. Delete `vault.yaml`, the AVP config, `argocd/manifests/` and
   `plausible/`, update `AGENTS.md`, and push. Run `helmfile apply` and
   `helm -n argocd uninstall manifests` in `argocd/`.
4. After the user confirms, delete the `vault` PVC and namespace.

Rollback: before step 4, revert the commits and re-run `helmfile apply`.
After step 4, Vault data is gone; restore from Infisical only.
