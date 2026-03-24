# Working with Claude on Move Big Rocks Instance Template

**Company:** DemandOps
**Repository:** Public template for private Move Big Rocks instance repos

## Critical Rules

1. **NO AI ATTRIBUTION IN GIT COMMITS.** No `Co-Authored-By`, no `Generated with`, nothing.
2. **Do not write secrets into tracked files.**
3. **Do not change the pinned core version unless explicitly asked.**

## What This Repo Is

The canonical starting point for customer deployments. Customers create a private repo from this template (e.g. `acme/mbr-prod`) which becomes their deployment control plane.

This repo is NOT a live instance. It is the template that shapes every instance repo.

## Key Files

- `mbr.instance.yaml` — desired state (domains, host, artifact refs, providers)
- `START_HERE.md` — primary agent handoff
- `agents/bootstrap.md` — detailed bootstrap checklist
- `deploy/` — service files, setup script, Caddyfile, upgrade runbook
- `deploy/UPGRADE.md` — step-by-step core upgrade process
- `extensions/desired-state.yaml` — extension configuration
- `scripts/read-instance-config.sh` — config parser/validator
- `branding/site.json` — branding overrides
- `security/` — threat model and review materials

## Changes to This Repo

Changes here affect every NEW instance repo created from the template. Existing instance repos are not updated automatically.

When editing, keep instructions generic (use `yourdomain.com`, `your-server-ip`, default ports 8080/8081) since each instance customizes for their environment.

## Related Docs

- [Customer Instance Setup](https://github.com/MoveBigRocks/platform/blob/main/docs/CUSTOMER_INSTANCE_SETUP.md)
- [Release Artifact Contract](https://github.com/MoveBigRocks/platform/blob/main/docs/RELEASE_ARTIFACT_CONTRACT.md)
