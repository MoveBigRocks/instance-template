# Move Big Rocks Instance Template

This tree is the canonical Move Big Rocks instance-template layout for deploying
Move Big Rocks, the AI-native service operations platform.

It is the canonical customer deployment-control-plane starting point inside the
public Move Big Rocks core repo.

A private instance repo is the deployment control plane for one live Move Big Rocks installation. It should contain desired state, deployment policy, branding, and extension configuration. It should not contain a long-lived fork of the core source tree.

## What This Source Tree Is

This source tree is:

- the starting point for private instance repos such as `acme/mbr-prod`
- the canonical home for the deployment-control-plane shape customers should use
- the place agents and humans should read when they want to understand what belongs in an instance repo

This source tree is not:

- the whole public core repo
- a live DemandOps or customer instance
- a place to store secrets
- a place to author first-party paid extension source

## Intended Use

1. Create a private repo from this template structure.
2. Fill in `mbr.instance.yaml`.
3. Add repository and environment secrets.
4. Open the repo in Codex or Claude Code.
5. Point the agent at `START_HERE.md`.
6. Let the agent deploy and operate the instance.
7. Use `scripts/read-instance-config.sh` to validate and inspect the non-secret desired state.
8. Use `scripts/validate-extension-desired-state.sh` before changing or deploying `extensions/desired-state.yaml`.
9. Review the `spec.fleet` settings and run the manual `Register Fleet` workflow if this instance should be registered for support, grandfathering, or future commercial transitions.

See also:

- [Customer Instance Setup](https://github.com/movebigrocks/platform/blob/main/docs/CUSTOMER_INSTANCE_SETUP.md)
- [Customer FAQ](https://github.com/movebigrocks/platform/blob/main/docs/CUSTOMER_FAQ.md)
- [Customer Onboarding Review](https://github.com/movebigrocks/platform/blob/main/docs/CUSTOMER_ONBOARDING_REVIEW.md)
- [Release Artifact Contract](https://github.com/movebigrocks/platform/blob/main/docs/RELEASE_ARTIFACT_CONTRACT.md)

## Contents

- `mbr.instance.yaml`
  Canonical desired state for one Move Big Rocks installation.
- `START_HERE.md`
  Single-file handoff for Codex or Claude Code.
- `agents/bootstrap.md`
  The first-run instructions an agent should follow.
- `branding/site.json`
  Customer-owned branding and copy overrides.
- `extensions/desired-state.yaml`
  Installed and planned extension refs.
- `.github/workflows/`
  Deployment, verification, and explicit fleet-registration workflows owned by the instance repo.
- `deploy/`
  Deploy scripts, service units, and host bootstrap assets owned by the instance repo.
- `security/`
  Threat-model and review materials for custom extensions.
- `scripts/read-instance-config.sh`
  Canonical parser and validator for `mbr.instance.yaml`.
- `scripts/validate-extension-desired-state.sh`
  Verifies that installed extension refs are real before deploy.
- `scripts/sync-from-template.sh`
  Pulls deploy and security scaffolding updates from this template into an
  existing instance repo, without touching instance identity or secrets.

## Operating Rules

- Pin core releases instead of tracking arbitrary commits.
- Pin extension artifact refs instead of storing proprietary extension source here.
- Validate extension desired-state refs before merge or deploy.
- Store custom extension source in separate repos.
- Keep customer-specific secrets in GitHub Actions secrets or another secret manager, not in this repo.
- Keep hosts, domains, artifact refs, buckets, and provider choices in `mbr.instance.yaml`.
- Keep fleet registration explicit. Every instance repo carries `spec.fleet`, but registration remains a manual control-plane action and the heartbeat stays disclosed, coarse, and optional for the running core platform.
- Default to one private instance repo only. Add a custom extension repo only when you are building custom extension logic.

## Syncing Template Updates Into an Existing Instance

New instance repos start from this template, but existing ones do not update
automatically. When the template's deploy or security scaffolding changes (for
example a new RFC in the deploy workflow or a sudoers tightening), pull those
changes into an existing instance repo with:

```bash
# Preview the diff without changing anything
scripts/sync-from-template.sh --dry-run

# Review the diff, then confirm to apply the mechanism changes
scripts/sync-from-template.sh
```

The script fetches the latest template, shows a diff of the non-instance-specific
scaffolding (workflows, deploy scripts, reconcile machinery, config reader,
security materials), and applies it only after you type `yes`. It never
overwrites instance identity or secrets: `mbr.instance.yaml`,
`extensions/desired-state.yaml`, `branding/site.json`, and any `*.env` /
`*secret*` / `.fleet-*` file are left untouched. Service unit files and the
Caddy/env examples often carry per-instance ports or domains, so they are shown
for manual review but never applied automatically.

After syncing, re-run `scripts/read-instance-config.sh` and
`scripts/validate-extension-desired-state.sh`, then review and commit.

## Export Status

This tree already includes the deployment workflows, deploy assets, and config
reader needed to materialize a working instance repo layout without manual
copying.

You can materialize that repo layout locally with:

```bash
scripts/export-instance-template.sh /absolute/path/to/acme-mbr-prod
```

Validate it before or after export with:

```bash
make validate-instance-template
```
