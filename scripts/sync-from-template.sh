#!/usr/bin/env bash
set -euo pipefail

# Sync deploy and security scaffolding from the Move Big Rocks instance template
# into this instance repo.
#
# It pulls the latest instance-template, shows a diff of the non-instance-specific
# scaffolding, and applies it only after you confirm. It never touches instance
# identity, secrets, or per-instance configuration:
#   - mbr.instance.yaml
#   - extensions/desired-state.yaml
#   - branding/site.json
#   - anything matching *.env / *secret* / .fleet-*
#
# Service unit files and Caddy/env examples often carry per-instance ports,
# domains, or resource limits, so they are shown for REVIEW but never applied
# automatically. Port any wanted changes to those by hand.
#
# Usage:
#   scripts/sync-from-template.sh [--dry-run] [--repo <git-url>] [--ref <ref>]
#
# Environment overrides:
#   MBR_TEMPLATE_REPO   git URL of the template (default: public instance-template)
#   MBR_TEMPLATE_REF    branch or tag to sync from (default: main)

TEMPLATE_REPO="${MBR_TEMPLATE_REPO:-https://github.com/MoveBigRocks/instance-template.git}"
TEMPLATE_REF="${MBR_TEMPLATE_REF:-main}"
DRY_RUN=false

usage() {
  sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --repo) TEMPLATE_REPO="${2:?--repo needs a value}"; shift 2 ;;
    --ref) TEMPLATE_REF="${2:?--ref needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Sanity: only run inside an instance repo. This guards against syncing a
# template's scaffolding into an unrelated tree.
if [[ ! -f "${REPO_ROOT}/mbr.instance.yaml" ]]; then
  echo "refusing to run: ${REPO_ROOT}/mbr.instance.yaml not found" >&2
  echo "run this from the root of an MBR instance repo" >&2
  exit 1
fi

# Non-instance-specific mechanism files that are safe to overwrite after review.
APPLY_PATHS=(
  ".github/workflows/production.yml"
  ".github/workflows/_check-environment.yml"
  ".github/workflows/_deploy.yml"
  ".github/workflows/verify-production.yml"
  ".github/workflows/verify-backup.yml"
  ".github/workflows/validate-extension-desired-state.yml"
  ".github/workflows/register-fleet.yml"
  ".github/workflows/manage-extensions.yml"
  ".github/workflows/commit-messages.yml"
  ".github/workflows/customer-zero.yml"
  ".github/scripts/validate-commit-message.sh"
  ".githooks/commit-msg"
  "deploy/setup.sh"
  "deploy/mbr-sudoers"
  "deploy/reconcile-extensions.sh"
  "deploy/EXTENSION_RECONCILIATION.md"
  "deploy/mbr-fleet-heartbeat.sh"
  "deploy/prometheus.service"
  "deploy/fail2ban/mbr-analytics.conf"
  "deploy/fail2ban/mbr-analytics-jail.conf"
  "scripts/read-instance-config.sh"
  "scripts/validate-extension-desired-state.sh"
  "scripts/sync-from-template.sh"
  "scripts/customer-zero-preflight.sh"
  "scripts/export-instance-template.sh"
  "security/extension-threat-model.md"
  "security/review-checklist.md"
)

# Shown for review, never auto-applied: commonly customized per instance
# (ports, resource limits, domains).
REVIEW_PATHS=(
  "deploy/mbr-blue.service"
  "deploy/mbr-green.service"
  "deploy/mbr-fleet-heartbeat.service"
  "deploy/mbr-fleet-heartbeat.timer"
  "deploy/Caddyfile.example"
  "deploy/env.example"
)

# Defensive guard: never allow instance identity, secrets, or per-instance
# config to be written, even if the allowlist above is edited by mistake.
is_protected() {
  case "$1" in
    mbr.instance.yaml|extensions/desired-state.yaml|branding/*) return 0 ;;
    *secret*|*.env|.env|.fleet-*) return 0 ;;
    *) return 1 ;;
  esac
}

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo "Fetching template ${TEMPLATE_REPO} (${TEMPLATE_REF})..."
if ! git clone --depth 1 --branch "${TEMPLATE_REF}" "${TEMPLATE_REPO}" "${TMP_DIR}/template" >/dev/null 2>&1; then
  echo "failed to clone template ${TEMPLATE_REPO} at ref ${TEMPLATE_REF}" >&2
  exit 1
fi
TEMPLATE_DIR="${TMP_DIR}/template"

CHANGED_APPLY=()
NEW_APPLY=()

echo
echo "=== Mechanism files (safe to apply after confirmation) ==="
for rel in "${APPLY_PATHS[@]}"; do
  if is_protected "${rel}"; then
    echo "SKIP (protected): ${rel}"
    continue
  fi
  src="${TEMPLATE_DIR}/${rel}"
  dst="${REPO_ROOT}/${rel}"
  if [[ ! -f "${src}" ]]; then
    continue
  fi
  if [[ ! -f "${dst}" ]]; then
    echo "--- ${rel} (new file, will be added) ---"
    NEW_APPLY+=("${rel}")
    continue
  fi
  if ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
    echo "--- ${rel} ---"
    diff -u "${dst}" "${src}" || true
    CHANGED_APPLY+=("${rel}")
  fi
done

REVIEW_CHANGED=()
echo
echo "=== Review-only files (NOT applied; may hold per-instance values) ==="
for rel in "${REVIEW_PATHS[@]}"; do
  src="${TEMPLATE_DIR}/${rel}"
  dst="${REPO_ROOT}/${rel}"
  [[ -f "${src}" ]] || continue
  if [[ ! -f "${dst}" ]] || ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
    echo "--- ${rel} (template differs; reconcile by hand) ---"
    diff -u "${dst:-/dev/null}" "${src}" 2>/dev/null || true
    REVIEW_CHANGED+=("${rel}")
  fi
done

# Combine changed and new files. Guard each expansion so an empty array does
# not trip `set -u` on bash 3.2.
TO_APPLY=( ${CHANGED_APPLY[@]+"${CHANGED_APPLY[@]}"} ${NEW_APPLY[@]+"${NEW_APPLY[@]}"} )

echo
if [[ ${#TO_APPLY[@]} -eq 0 ]]; then
  echo "Mechanism files are already in sync with the template."
else
  echo "${#TO_APPLY[@]} mechanism file(s) differ from the template:"
  printf '  %s\n' "${TO_APPLY[@]}"
fi
if [[ ${#REVIEW_CHANGED[@]} -gt 0 ]]; then
  echo "${#REVIEW_CHANGED[@]} review-only file(s) differ and need manual reconciliation:"
  printf '  %s\n' "${REVIEW_CHANGED[@]}"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo
  echo "Dry run: no files were changed."
  exit 0
fi

if [[ ${#TO_APPLY[@]} -eq 0 ]]; then
  exit 0
fi

echo
read -r -p "Apply the ${#TO_APPLY[@]} mechanism change(s) above? Type 'yes' to proceed: " REPLY < /dev/tty
if [[ "${REPLY}" != "yes" ]]; then
  echo "Aborted. No files were changed."
  exit 0
fi

for rel in "${TO_APPLY[@]}"; do
  if is_protected "${rel}"; then
    echo "refusing to write protected path: ${rel}" >&2
    exit 1
  fi
  src="${TEMPLATE_DIR}/${rel}"
  dst="${REPO_ROOT}/${rel}"
  mkdir -p "$(dirname "${dst}")"
  cp -p "${src}" "${dst}"
  echo "applied: ${rel}"
done

echo
echo "Done. Instance identity, secrets, and per-instance config were not touched."
echo "Next steps:"
echo "  1. Reconcile any review-only files listed above by hand."
echo "  2. scripts/read-instance-config.sh mbr.instance.yaml"
echo "  3. scripts/validate-extension-desired-state.sh extensions/desired-state.yaml"
echo "  4. Review the diff and commit."
