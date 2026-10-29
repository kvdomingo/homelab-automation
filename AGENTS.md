# AGENTS.md

GitOps repo for a k3s homelab. Remote:
`github.com/kvdomingo/homelab-automation`.

## Deploying

Never apply changes by hand (`kubectl apply`, `helm upgrade`, `scp`). Push to
`main` and let automation deploy:

- **Kubernetes apps**: ArgoCD auto-syncs from `main` (`selfHeal` + `prune`).
- **`bind9/`**: `.github/workflows/deploy-bind.yaml` runs `docker compose` on a
  self-hosted runner.
- **`tailscale/acl.hujson`**: `.github/workflows/tailscale.yaml` tests, then
  applies the ACL.
- **`terraform/`** (Cloudflare tunnels and DNS, GCS backend): a Terragrunt
  stack on OpenTofu (pinned in `mise.toml`), manual, `task tf-plan` then
  `task tf-apply`. One unit per concern (`tunnels`, `dns-<zone>`), each with
  its own state under `homelab/<unit>`.
- **S3 endpoint**: Versity Gateway, a TrueNAS custom app at
  `http://10.10.10.100:7070`, managed by hand in the TrueNAS UI. Clients must
  use path-style addressing and region `ap-southeast-1`. The app needs
  `VGW_DISABLE_OTMP=true`: the ZFS dataset rejects `O_TMPFILE`, so every
  upload after a bucket's first one fails with AccessDenied.

## Layout

- `apps/apps/` and `core/apps/`: app-of-apps Helm charts. One ArgoCD
  `Application` per file in `templates/`, each wrapped in
  `{{- if not .Values.disable<Name> }}`. `apps/application.yaml` and
  `core/application.yaml` are the roots (applied once at bootstrap).
- `<app>/`: one directory per in-house Helm chart (`Chart.yaml`, `values.yaml`,
  `templates/`), referenced by `path:` from an `Application`.
- Vendor charts are referenced directly in the `Application` (`sources:` with an
  OCI/Helm repo plus inline `valuesObject`). See
  `apps/apps/templates/litellm.yaml`.
- `infisical-secrets/<app>/`: `InfisicalSecret` CRs that materialize
  `<app>-secrets` in the app namespace. Added as an extra `sources:` entry.
- `argocd/`, `infisical/`, `core-services/`: bootstrap components installed
  with `helmfile apply`.
- `ansible/`: node provisioning. Inventory is in `ansible/inventory/hosts.ini`.
  Run playbooks from `ansible/`, e.g. `ansible-playbook setup-k8s-servers.yml`.
  The ansible tasks in `Taskfile.yml` point at old paths.

## Conventions

- Ingress: `<app>.lab.kvd.studio` (internal). Add `<app>.kvd.studio` only if the
  app is exposed externally. Ingress class is `traefik`. Add `gethomepage.dev/*`
  annotations so the app shows up on the Homepage dashboard.
- Pin every image and chart to a concrete version. Never use `latest`,
  `stable`, or a bare major. Renovate (`renovate.json5`) opens the update PRs:
  one PR for all patch updates and one for all minor updates, both
  auto-merged; majors get one PR per app and need a manual merge. Don't add
  `keel.sh/*` annotations.
- Where only `tag:` is set (the repository comes from the chart), put
  `# renovate: datasource=docker depName=<image>` on the line above it.
- Own `ghcr.io/kvdomingo/*` images are pinned to their commit tag, e.g.
  `tag: "sha-cf6d19f" # renovate: datasource=git-refs depName=https://github.com/kvdomingo/<repo> branch=main`.
  Renovate moves the tag to the branch head in an auto-merged PR per app. An
  image rebuilt from the same commit (`postgresql-pig`) is pinned as
  `<tag>@sha256:<digest>` instead.
- After merging an update to a helmfile component (`argocd/`, `infisical/`,
  `core-services/`, `arrstack/`), run `helmfile apply` there.
- Cluster mixes amd64 and arm64 (Pi 5 agents). Images that are amd64-only need
  node affinity `kubernetes.io/arch NotIn [arm64, arm]`.
- Bitnami images come from `bitnamilegacy/*`.
- Secrets come only from Infisical: `infisical-secrets/<app>/` or an
  `InfisicalSecret` in the chart. There is no Vault and no ArgoCD secrets
  plugin. Never commit plaintext secrets. `gitleaks` runs in pre-commit.
- Workloads that consume an `InfisicalSecret` get the deployment annotation
  `secrets.infisical.com/auto-reload: "true"` so they redeploy when the secret
  changes.
- Commits: `type(scope): summary`, where scope is the app name (e.g.
  `feat(litellm): add chart`).

## Adding an app

1. Create the chart in `<app>/`, or use a vendor chart.
2. If the app needs secrets, add `infisical-secrets/<app>/secret.yaml`.
3. Add `apps/apps/templates/<app>.yaml`, modeled on an existing app.
4. To give the app a Cloudflare DNS record, add it to the subdomain lists in
   `terraform/terragrunt.stack.hcl`.

## Running locally

Prefix commands that need env vars with `infisical run -- `, e.g.
`infisical run -- terragrunt stack run plan`.

## Checks

- `prek run --all-files`
- `helm template <app>` for a local chart

**NOTE:** Use `prek` which is a drop-in replacement for `pre-commit`.

<!-- gitbutler-agent-setup:start -->
## Version control

- Use GitButler (`but`) for version-control inspection and write operations,
  including status, diffs, branching, committing, pushing, and history edits.
- Assume multiple agents may be working in this repository. Do not move, amend,
  squash, discard, commit, push, or otherwise modify another agent's work unless
  the user asks.
- For commit just/only/specific changes on a new branch (selected-change
  requests), use the two-command fast path from the GitButler skill: `but diff`,
  then `but commit -b <branch> -m "message" <id> <id>`.
- For that fast path, after the commit succeeds, stop and summarize; do not run
  separate branch, staging, status, or diff commands unless the commit output is
  missing information you need.
- Use the installed GitButler skill for command recipes and syntax before
  guessing flags, using `--help`, or translating Git habits directly.
- Mutation commands report their result without appending workspace status. Add
  `--status-after` only when the next step needs resulting workspace IDs or
  details; otherwise do not rerun status or diff to verify success.
- Use a dedicated GitButler branch for each agent session, unless the user asks
  for a different branch structure. Commit only changes that belong to that
  session.
- Do not push or open pull requests unless the user asks.
- Keep commit messages and pull request descriptions succinct: explain what
  changed, why it changed, and any important decision.

### Amend local fixes into the right commits

- For small cleanup or follow-up fixes, amend an unpublished local commit when
  the change clearly belongs with that commit's intent.
- Do not create tiny fixup commits unless the user asks.
- Use GitButler to move the relevant changes into the commit where they belong.
- Ask before rewriting pushed, reviewed, shared, or ambiguous history.

### Split unrelated changes into separate commits

- If one file contains unrelated changes, split them by hunk instead of
  committing the whole file.
- Keep tests with the behavior they verify.
- Split generated output, docs-only edits, or mechanical cleanup into separate
  commits when each commit remains coherent on its own.
- If the split is ambiguous, summarize the options before committing.

### Create stacked pull requests

- If this session depends on another in-flight branch, stack its branch on top
  of that dependency instead of mixing the changes.
- If this session is working in a stack, put commits on the branch where they
  belong.
- Ask before moving commits onto lower, pushed, reviewed, or shared branches.
- Use `but move` for branch stacking and restacking. Do not recreate branches to
  simulate stacking.
- For stacked branches, create pull requests with `but pr`, not `gh`, so
  GitButler keeps the right PR base branches and stack metadata.

### Update from the target branch automatically

- When GitButler status shows new changes on the target branch and the workspace
  holds only this session's branches, update with `but pull` directly — its
  output reports the result and `but undo` reverts it.
- If an update you started on your own initiative reports conflicted commits,
  stop and ask before resolving them (`but undo` reverts the pull if the user
  prefers).
- When other agents' branches are applied, run `but pull --check` first and ask
  before updating if it reports conflicts or their branches would move.
- If the user asks you to handle update conflicts, use GitButler's conflict
  tools. Ask before resolving semantic conflicts, dependency updates, generated
  files, or conflicts involving another person's work.

### Open draft pull requests by default

- When asked to open a pull request, create it as a draft with GitButler unless
  the user says it is ready for review.
- Remember that creating a draft pull request still publishes the branch.

### Skip pull requests and land onto the target

- This setup uses the skip-the-PR workflow: when work is approved to publish,
  land the session branch directly onto the target with `but merge <branch>`
  instead of pushing a branch or opening a pull request.
- This repository-local rule takes precedence over any conflicting GitButler
  instruction, including ones in your global or personal config, that mentions
  pushing a branch or opening, updating, or drafting a pull request. Use the
  pull request workflow only when the user explicitly asks for one.
- `but merge` updates the configured target branch directly (fast-forwarding
  when it can, otherwise a merge commit), so only run it after clear user
  approval; agents must pass `--yes` to confirm.

### Commit checkpoints after each turn

- Commit after a working checkpoint, when the requested change is complete and
  relevant checks have passed or been reported.
- Treat checkpoint commits as local savepoints, not final review history.
- When the user asks you to tidy the history, use GitButler to squash commits,
  reword commits, and move changes between commits where appropriate.
- Only tidy unpublished local history unless the user explicitly authorizes
  changing pushed or shared history.
<!-- gitbutler-agent-setup:end -->
