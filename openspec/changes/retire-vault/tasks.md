# Tasks

## 1. Move Applications to native sources

- [x] 1.1 Drop `plugin:` from `atuin`, `apod`, `banyuhay`, `discai`,
      `excalidraw`, `hd2-app`, `it-tools`, `n8n`, `primerdriver` in
      `apps/apps/templates/`; verify `helm template apps/apps` renders each
      with `path:` and no `plugin:`
- [x] 1.2 Move `delphitools` and `home-assistant` `HELM_VALUES` verbatim
      under `helm.valuesObject`, keeping the renovate comments; verify
      `helm template apps/apps` shows the same values and
      `grep -rn 'plugin:' apps/apps core/apps` returns nothing
- [x] 1.3 Run `prek run --all-files` and verify it passes
- [ ] 1.4 Commit and land on `main` after approval; verify in ArgoCD that
      all eleven apps are Synced and Healthy with no resource recreated

## 2. Audit Vault (manual, read-only)

- [ ] 2.1 List every KV path in Vault (`vault kv list` under each mount)
      and verify each one has an Infisical counterpart or is confirmed
      unused by the user

## 3. Remove Vault and the plugin

- [ ] 3.1 Delete `core/apps/templates/vault.yaml` and any `disableVault`
      value; verify `helm template core/apps` has no `vault` Application
- [ ] 3.2 Remove the `avp` and `avp-helm` sidecars, the `download-tools`
      init container and the `cmp-plugin`/`custom-tools` volumes from
      `argocd/values.yaml`; verify `grep -n 'avp\|custom-tools\|cmp-plugin'
      argocd/values.yaml` only hits upstream commented examples
- [ ] 3.3 Delete `argocd/manifests/` (tracked `cm.yaml` and the gitignored
      local `secrets.yaml`) and its release in `argocd/helmfile.yaml`;
      verify `ls argocd/manifests` fails and
      `helmfile -f argocd/helmfile.yaml lint` passes
- [ ] 3.4 Delete `plausible/`; verify `grep -rIn '<path:\|avp\.kubernetes\.io'
      --exclude-dir=openspec .` returns nothing
- [ ] 3.5 Update `AGENTS.md` so Infisical is the only secrets mechanism;
      verify `grep -n vault-plugin AGENTS.md` returns nothing
- [ ] 3.6 Run `prek run --all-files`, commit, and land on `main` after
      approval; verify ArgoCD prunes the `vault` Application and all apps
      stay Healthy

## 4. Cluster cleanup (manual, after approval)

- [ ] 4.1 In `argocd/`, run `helmfile apply` and
      `helm -n argocd uninstall manifests`; verify the repo-server pod has
      no `avp` containers and `kubectl -n argocd get cm/cmp-plugin
      secret/vault-configuration` returns NotFound
- [ ] 4.2 After user confirmation, delete the `vault` PVC and namespace;
      verify `kubectl get ns vault` returns NotFound

## Workflow follow-up

- Archive the change once group 4 is done.
