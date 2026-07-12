#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-apply-all}"

ROOT_DIR="${MBR_RECONCILE_ROOT_DIR:-/opt/mbr}"
DESIRED_STATE_PATH="${MBR_RECONCILE_DESIRED_STATE_PATH:-${ROOT_DIR}/extensions/desired-state.yaml}"
ARTIFACT_DIR="${MBR_RECONCILE_ARTIFACT_DIR:-${ROOT_DIR}/reconcile-artifacts/extensions}"
ACTOR="${MBR_RECONCILE_ACTOR:-system:reconcile-extensions}"
TOOL="${ROOT_DIR}/tools/reconcile-extensions"
RUNTIME_MANIFEST_PATH="${ARTIFACT_DIR}/runtime-manifest.json"
PLAN_PATH="${ARTIFACT_DIR}/plan.json"
APPLY_PATH="${ARTIFACT_DIR}/apply.json"
CHECK_PATH="${ARTIFACT_DIR}/check.json"

if [[ ! -x "${TOOL}" ]]; then
  echo "missing reconciler tool: ${TOOL}" >&2
  exit 1
fi

if [[ ! -f "${DESIRED_STATE_PATH}" ]]; then
  echo "missing desired state file: ${DESIRED_STATE_PATH}" >&2
  exit 1
fi

mkdir -p "${ARTIFACT_DIR}"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/.env"
  set +a
fi

# Reconcile is a short-lived process that reads the same extension
# runtime config the blue-green cores use, but systemd only sets
# MBR_SLOT on the long-running mbr-<slot>.service units. Without it
# the socket dispatcher looks at the un-slot-scoped path and the check
# phase reports every extension as unhealthy. Resolve the active slot
# from .active-slot so reconcile targets the serving core's sockets.
# See RFC-0016.
if [[ -z "${MBR_SLOT:-}" && -f "${ROOT_DIR}/.active-slot" ]]; then
  MBR_SLOT="$(tr -d '[:space:]' < "${ROOT_DIR}/.active-slot")"
  if [[ -n "${MBR_SLOT}" ]]; then
    export MBR_SLOT
  fi
fi

case "${MODE}" in
  plan)
    "${TOOL}" plan \
      --desired-state "${DESIRED_STATE_PATH}" \
      --output "${PLAN_PATH}" \
      --runtime-manifest-out "${RUNTIME_MANIFEST_PATH}" \
      --actor "${ACTOR}"
    ;;
  apply-all)
    "${TOOL}" plan \
      --desired-state "${DESIRED_STATE_PATH}" \
      --output "${PLAN_PATH}" \
      --runtime-manifest-out "${RUNTIME_MANIFEST_PATH}" \
      --actor "${ACTOR}"

    "${TOOL}" apply \
      --desired-state "${DESIRED_STATE_PATH}" \
      --output "${APPLY_PATH}" \
      --runtime-manifest-out "${RUNTIME_MANIFEST_PATH}" \
      --actor "${ACTOR}"

    "${TOOL}" check \
      --desired-state "${DESIRED_STATE_PATH}" \
      --output "${CHECK_PATH}" \
      --runtime-manifest-out "${RUNTIME_MANIFEST_PATH}" \
      --actor "${ACTOR}"
    ;;
  check)
    "${TOOL}" check \
      --desired-state "${DESIRED_STATE_PATH}" \
      --output "${CHECK_PATH}" \
      --runtime-manifest-out "${RUNTIME_MANIFEST_PATH}" \
      --actor "${ACTOR}"
    ;;
  *)
    echo "unsupported mode: ${MODE}" >&2
    echo "usage: reconcile-extensions.sh [plan|apply-all|check]" >&2
    exit 2
    ;;
esac
