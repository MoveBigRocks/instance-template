# START HERE

Give this file to Codex or Claude Code when setting up or operating this Move Big Rocks instance.

## Mission

Take this repo from configuration to a working Move Big Rocks installation.

The target outcome is:

- core Move Big Rocks deployed on the target Linux host
- admin access working
- app, admin, and API health checks passing
- outbound email configured
- optional first-party extensions installed when requested
- no secrets written into tracked files

## Read These Files First

1. `mbr.instance.yaml`
2. `scripts/read-instance-config.sh`
3. `scripts/validate-extension-desired-state.sh`
4. `agents/bootstrap.md`
5. `extensions/desired-state.yaml`
6. `deploy/README.md`
7. `.github/workflows/production.yml`
7b. `deploy/UPGRADE.md` — step-by-step core version upgrade process
8. `branding/site.json`
9. `security/extension-threat-model.md`
10. `security/review-checklist.md`
11. `https://github.com/movebigrocks/platform/blob/main/docs/INSTANCE_AND_EXTENSION_LIFECYCLE.md` when custom extension work is involved

## Default Rules

- This repo is the deployment control plane for one live Move Big Rocks installation.
- Do not change Move Big Rocks core source code from this repo.
- Do not write secrets into git-tracked files.
- Do not change the pinned core version unless explicitly asked.
- Do not treat the public first-party bundles as paid-only extensions.
- Do not activate self-built extensions before the threat model and review checklist are complete.
- Do not use the generic runtime for privileged auth or connector extensions.
- Do not add silent phone-home behavior beyond the disclosed fleet registration and optional heartbeat owned by this repo.

## What You Should Do

1. Read `mbr.instance.yaml` and understand the desired state.
2. Run `scripts/read-instance-config.sh mbr.instance.yaml` and confirm the parsed host, domains, pinned artifact refs, email provider, and storage provider.
3. Run `scripts/validate-extension-desired-state.sh extensions/desired-state.yaml` before any deploy that changes extension refs.
4. Check that the required repository or environment secrets exist.
5. Bootstrap the Linux host if needed.
6. Deploy the pinned Move Big Rocks core release.
7. Verify:
   - app health
   - admin health
   - API health
   - admin login
   - outbound email
8. If `spec.fleet` is enabled, run the manual `Register Fleet` workflow after the first successful deploy and verify the disclosure language with the operator.
9. Create the first admin user if needed.
10. Create the primary workspace if needed.
11. Review `extensions/desired-state.yaml`.
12. Install, validate, configure, and activate any requested extensions, using the public signed first-party bundle refs when applicable.
13. Apply branding overrides from `branding/site.json`.
14. Report what changed, what is still missing, and any risks.

## Required Inputs

You may need:

- SSH access to the Linux host
- DNS already pointing at the host
- outbound email credentials for the selected provider
- object storage credentials when using `s3-compatible` storage
- admin email address
- extension refs and any instance-specific configuration values

The human should usually provide only those inputs.
The agent should handle validation, repo setup steps, deployment, health
verification, extension install, and follow-up operational checks.

## Repo Model

For most customers, this instance repo is the only private repo they need.

A second repo is needed only if the customer is building a custom extension with real logic. Simple branding and configuration changes stay here.

## Success Conditions

The task is complete when:

- the pinned core version is running
- the health checks pass
- admin access works
- outbound email works
- any enabled fleet registration/heartbeat path is disclosed and configured as requested
- this repo accurately reflects the deployed desired state
- any installed extension has passed the required review gates
