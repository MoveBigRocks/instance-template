# Agent Bootstrap Instructions

Use this file when onboarding a fresh Move Big Rocks instance.

`START_HERE.md` is the primary agent handoff. This file provides the more detailed execution checklist behind that handoff.

## Goal

Take a new customer from an empty Linux host to a working Move Big Rocks instance with:

- core deployed
- admin access created
- health checks passing
- outbound email configured
- optional first-party extensions installed and activated when requested

## Required Inputs

- SSH access to the Linux host
- domain names for `app`, `admin`, and `api`
- storage credentials
- outbound email credentials
- admin email address
- access to review the private instance repo protection rules and deployment environments
- any purchased extension refs or local bundle files

## Workflow

1. Read `mbr.instance.yaml`.
2. Run `scripts/read-instance-config.sh mbr.instance.yaml` and confirm the parsed values.
3. Read `START_HERE.md`.
4. Confirm the pinned core artifact refs and target host.
5. Review the private instance repo control-plane protections before deployment:
   - branch protection or equivalent merge gate on the default branch
   - required reviewers for production deployment environments
   - least-privilege secrets scoped to the environments that actually need them
   - audit visibility for secret changes and production rollouts
6. Bootstrap the host with the deploy assets.
7. Configure runtime secrets outside git.
8. Deploy the pinned core release.
9. Verify:
   - app health endpoint
   - GraphQL availability
   - admin login flow
   - outbound email delivery
10. If `spec.fleet` is enabled, run the manual `Register Fleet` workflow and confirm the operator understands the disclosed registration and heartbeat behavior.
11. Create the admin user if needed.
12. Create the primary workspace if needed.
13. Create or confirm one dedicated preview workspace for extension preview if the instance will run optional extensions.
14. Review `extensions/desired-state.yaml`.
15. Install any requested extensions.
16. Run the extension threat model and review checklist before activation.
17. Activate new or upgraded workspace-scoped extensions in the preview workspace first.
18. Apply branding overrides from `branding/site.json`.
19. Enable public routes only after review gates pass.
20. Report the final state, gaps, and risks.

## Guardrails

- Do not change the pinned core version unless explicitly asked.
- Do not assume the public first-party bundles require a license token.
- Do not activate self-built extensions before the threat-model and review checklist are complete.
- Do not use the generic runtime for privileged auth or connector extensions.
- Do not write secrets into tracked files.
- Do not treat the private instance repo as “just documentation”; it is part of the production control plane and needs real review gates.
- Do not proceed to production deployment if repo protections or deployment-environment reviewers are missing without explicitly calling that out as a risk.
- Do not hide fleet registration or heartbeat behavior from the operator. Registration is explicit and the heartbeat remains optional.
- Keep custom app source code in separate repos unless the customization is a simple content override.
- Default to one private instance repo only. Introduce a second repo only when building a custom extension with real logic.
