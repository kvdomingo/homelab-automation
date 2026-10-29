# Tasks

## 1. GitHub App and credentials (manual + this repo)

- [x] 1.1 (Manual, GitHub) Create a GitHub App on `kvdomingo` with Metadata
      read, Pull requests read, Commit statuses read/write; install it on
      `kvdomingo/primerdriver` only. Verify the installation page lists only
      primerdriver.
- [x] 1.2 (Manual, Infisical) Create an Infisical project for ArgoCD holding the
      App ID, installation ID, and private key. Verify the three keys exist in
      the `prod` env.
- [x] 1.3 Add `infisical-secrets/argocd/secret.yaml` producing
      `argocd-notifications-secret` (`github-appID`, `github-installationID`,
      `github-privateKey`) and repo-creds `github-app-primerdriver`
      (`url: https://github.com/kvdomingo/primerdriver`, `githubAppID`,
      `githubAppInstallationID`, `githubAppPrivateKey`, label
      `argocd.argoproj.io/secret-type: repo-creds`). Verify
      `prek run --all-files` passes (gitleaks finds nothing).
- [x] 1.4 Add `core/apps/templates/argocd-secrets.yaml` (wrapped in
      `disableArgocdSecrets`) syncing `infisical-secrets/argocd/` into `argocd`.
      Verify `helm template core/apps` renders it; after merge, verify both
      Secrets exist in `argocd`.

## 2. ArgoCD notifications

- [x] 2.1 In `argocd/values.yaml`, set `notifications.secret.create: false` and
      add the `service.github` notifier using `$github-appID`,
      `$github-installationID`, `$github-privateKey`. Verify `helmfile template`
      in `argocd/` renders the notifier and no `argocd-notifications-secret`.
- [x] 2.2 Add the `preview-pending`, `preview-success`, `preview-failure`
      templates (context `preview/primerdriver`, `repoURLPath`/`revisionPath`
      from the `preview.kvd.studio/*` annotations, success `targetURL` = first
      ingress host) and the `on-preview-status` trigger with the three
      conditions and `oncePer` from design.md. Verify `helmfile template` output
      contains them.
- [x] 2.3 After merge, run `helmfile apply` in `argocd/`. Verify
      `argocd-notifications-controller` logs show no config or auth errors.

## 3. primerdriver chart: blue-green Rollout

- [x] 3.1 Replace `templates/deployment.yaml` with `templates/rollout.yaml`
      (`argoproj.io/v1alpha1` `Rollout`, same pod template, `minReadySeconds`,
      `progressDeadlineSeconds`, `progressDeadlineAbort`, `strategy.blueGreen`
      with `activeService`, `previewService`, `scaleDownDelaySeconds`) driven by
      new `rollout.*` values (30 / 300 / true / 600). Verify
      `helm template primerdriver` renders a Rollout and no Deployment.
- [x] 3.2 Add `templates/service-preview.yaml` (`<fullname>-preview`, same ports
      and selector) and point the HPA `scaleTargetRef` at the Rollout. Verify
      `helm template primerdriver --set autoscaling.enabled=true` shows
      `kind: Rollout` in the HPA.
- [x] 3.3 Verify `prek run --all-files` passes and the Renovate `image.tag`
      comment is unchanged.
- [x] 3.4 After merge, verify the ArgoCD app is Healthy,
      `kubectl argo rollouts get rollout primerdriver -n primerdriver` shows a
      promoted stable ReplicaSet, and
      `https://primerdriver.kvd.studio/api/health` answers.
- [x] 3.5 Verify the production gate: on the next tag bump, watch two
      ReplicaSets run, the switch happen after ~30s of readiness, and the old
      ReplicaSet scale down after 10 minutes.

## 4. primerdriver CI (kvdomingo/primerdriver repo)

- [x] 4.1 In `.github/workflows/build-and-push.yml`, add the `pull_request`
      trigger, set `DOCKER_METADATA_PR_HEAD_SHA: "true"`, and change concurrency
      to `build-${{ github.ref }}`. Verify a test PR publishes
      `ghcr.io/kvdomingo/primerdriver:sha-<first 7 of head sha>` and a push to
      `main` still publishes its `sha-` tag.

## 5. Preview ApplicationSet

- [x] 5.1 Add `apps-dev/apps/templates/primerdriver-previews.yaml` (wrapped in
      `disablePrimerDriverPreviews`): `goTemplate`, `pullRequest.github`
      generator with `requeueAfterSeconds: 60` and
      `appSecretName: github-app-primerdriver`, the Application template,
      `valuesObject` overrides, and the `preview.kvd.studio/*` and subscription
      annotations from design.md. Verify `helm template apps/apps` renders it
      with Go template braces intact for the ApplicationSet controller.
- [x] 5.2 Document the preview pattern in `AGENTS.md` (Layout or Conventions:
      per-PR previews via ApplicationSet, host `<app>-pr-<n>.lab.kvd.studio`,
      shared `<app>-preview` namespace, `preview/<app>` status). Verify the text
      matches what 5.1 deploys.
- [x] 5.3 After merge, open a test PR on primerdriver. Verify
      `primerdriver-pr-<n>` appears in ArgoCD,
      `https://primerdriver-pr-<n>.lab.kvd.studio` serves the PR build over
      valid TLS, the head commit gets `pending` then `success` with the preview
      link, and the preview is absent from Homepage.
- [x] 5.4 Push a commit that breaks `/api/health` to the test PR. Verify the new
      head gets `failure` (not a stale `success`) and production is unaffected.
- [x] 5.5 Close the test PR. Verify within 5 minutes the Application and all its
      resources are gone from `primerdriver-preview`.
- [x] 5.6 (Manual, bootstrap) After merge, `kubectl apply -f
      apps-dev/application.yaml`. Verify `apps-dev` is Synced/Healthy, owns
      `primerdriver-previews`, and `apps-prod` no longer lists it.

## 6. Merge gate and Renovate

- [x] 6.1 (Manual, GitHub) Add branch protection on primerdriver `main`
      requiring the `preview/primerdriver` status. Verify a PR with a pending
      preview shows "Merging is blocked".
- [x] 6.2 Add `kvdomingo/primerdriver` to `repositories` in
      `renovate/templates/configmap.yaml`. Verify `helm template renovate`
      renders it; after the next run, verify Renovate opens primerdriver's
      onboarding PR.
- [x] 6.3 (primerdriver repo) Merge the onboarding PR with a `renovate.json`
      that auto-merges minor and patch updates (`automergeType: pr`) and leaves
      majors manual. Verify the next Renovate dependency PR gets a preview and
      merges only after `preview/primerdriver` is `success`.

## 7. Fast preview failure

- [x] 7.1 Add `primerdriver/templates/smoke-test.yaml` (wrapped in
      `smokeTest.enabled`, default false): `PreSync` hook Job with
      `BeforeHookCreation`, `backoffLimit: 0`, `activeDeadlineSeconds: 900`, the
      app image, the chart's affinity, and a script that starts the server and
      polls `localhost:<port>/api/health` for `smokeTest.timeoutSeconds` (120).
      Enable it in the preview `valuesObject`. Verify `helm template
      primerdriver --set smokeTest.enabled=true` renders the Job and the default
      render does not.
- [x] 7.2 Update `on-preview-status` in `argocd/values.yaml`: success also
      requires operation phase `Succeeded`; failure also fires on operation
      phase `Failed`/`Error` for the current image tag. After merge, run
      `helmfile apply` in `argocd/`.
- [x] 7.3 After merge, push a commit that breaks `/api/health` to a test PR.
      Verify `failure` posts within 5 minutes of its image being published and
      no `success` follows; push a fix and verify `success`.

## Workflow follow-up

- Archive the change once all tasks are done and verified.
