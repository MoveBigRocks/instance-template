# Extension Desired-State Reconciliation

`extensions/desired-state.yaml` is the declarative source of truth for which
extensions this instance runs. The deploy and verify workflows converge the live
instance onto that file.

## How It Works

The production deploy workflow:

- generates a runtime manifest from `extensions/desired-state.yaml`
- pulls the required service-backed runtime binaries named in that manifest
- runs the packaged `reconcile-extensions` tool on the host to plan, apply, and
  check desired extension state
- archives `plan.json`, `apply.json`, `check.json`, and the generated
  `runtime-manifest.json` as workflow artifacts
- fails closed when the installed bundle state or runtime health drifts from the
  declared desired state

The verify workflow re-runs the `check` phase and archives the result, so a
green deploy is backed by evidence that desired state, runtime rollout, and the
installed-extension rows in PostgreSQL agree.

## Why It Matters

Without this flow, three layers drift apart:

- `extensions/desired-state.yaml`
- the generated runtime manifest used for deployment
- the live `installed_extensions` rows in PostgreSQL

A runtime that moves ahead of its installed bundle version in the database is
exactly the failure this convergence prevents.

## Desired-State Shape

`extensions/desired-state.yaml` has two lists:

- `installed` entries are reconciled onto the instance. Each entry names the
  extension `slug`, its `source` (for example `oci`), the pinned artifact `ref`,
  `publisher`, `kind`, `scope`, `risk`, whether a license is required, the target
  `workspace`, whether to `activate`, and a `verification` block. Pin the `ref`
  to a released, immutable artifact tag.
- `planned` entries are intent only. They are not reconciled and carry no
  artifact ref, so they are a safe place to record extensions you mean to adopt.

## Operating Rule

Treat extension changes as a declarative rollout:

1. edit `extensions/desired-state.yaml`
2. run `scripts/validate-extension-desired-state.sh extensions/desired-state.yaml`
3. deploy the repo to `main`
4. confirm the reconciliation artifacts are clean

Manual `mbr extensions ...` commands are repair tools, not the normal source of
truth.

## Reconciliation Artifacts

Each rollout leaves behind, as workflow artifacts:

- `artifacts/reconcile/plan.json`
- `artifacts/reconcile/apply.json`
- `artifacts/reconcile/check.json`
- `artifacts/reconcile/runtime-manifest.json`

Those artifacts are the evidence that desired state, runtime rollout, and
installed-extension state converged together. The extension control plane is
healthy when a commit that changes `extensions/desired-state.yaml` deploys
cleanly to `main`, passes verification on the first run, and leaves a clean
reconciliation artifact set with no manual post-deploy extension action behind.
