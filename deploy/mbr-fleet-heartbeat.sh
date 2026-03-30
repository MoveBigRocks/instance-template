#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/opt/mbr}"
ENV_FILE="${ROOT_DIR}/.env"
FLEET_CONFIG_FILE="${ROOT_DIR}/.fleet-config.env"
FLEET_SECRET_FILE="${ROOT_DIR}/.fleet-secret.env"

if [[ ! -f "${ENV_FILE}" || ! -f "${FLEET_CONFIG_FILE}" ]]; then
  exit 0
fi

set -a
source "${ENV_FILE}"
source "${FLEET_CONFIG_FILE}"
if [[ -f "${FLEET_SECRET_FILE}" ]]; then
  source "${FLEET_SECRET_FILE}"
fi
set +a

if [[ "${MBR_FLEET_HEARTBEAT_ENABLED:-false}" != "true" ]]; then
  exit 0
fi

if [[ -z "${MBR_FLEET_API_URL:-}" || -z "${MBR_FLEET_INSTANCE_ID:-}" || -z "${MBR_FLEET_TRACKING_SECRET:-}" || -z "${DATABASE_DSN:-}" ]]; then
  exit 0
fi

query_sql() {
  local statement="$1"
  psql "${DATABASE_DSN}" -v ON_ERROR_STOP=1 -At -c "${statement}"
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

workspace_count="$(query_sql "SELECT COUNT(*)::text FROM core_platform.workspaces WHERE deleted_at IS NULL;")"
activity_count="$(query_sql "SELECT GREATEST(
  COALESCE((SELECT COUNT(*) FROM core_service.cases WHERE created_at >= NOW() - INTERVAL '30 days'), 0),
  COALESCE((SELECT COUNT(*) FROM core_service.conversation_sessions WHERE last_activity_at >= NOW() - INTERVAL '30 days'), 0),
  COALESCE((SELECT COUNT(*) FROM core_service.form_submissions WHERE COALESCE(submitted_at, created_at) >= NOW() - INTERVAL '30 days'), 0)
)::text;")"
extensions_json="$(query_sql "SELECT COALESCE(
  json_agg(
    json_build_object(
      'slug', slug,
      'version', version,
      'status', status
    )
    ORDER BY slug
  )::text,
  '[]'
)
FROM (
  SELECT slug, version, status
  FROM core_platform.installed_extensions
  WHERE deleted_at IS NULL
  ORDER BY slug ASC
) AS ext;")"

activity_bucket="0"
if [[ "${activity_count}" =~ ^[0-9]+$ ]]; then
  if (( activity_count >= 101 )); then
    activity_bucket="100+"
  elif (( activity_count >= 11 )); then
    activity_bucket="11-100"
  elif (( activity_count >= 1 )); then
    activity_bucket="1-10"
  fi
fi

payload="$(cat <<EOF
{"instance_id":"$(json_escape "${MBR_FLEET_INSTANCE_ID}")","tracking_secret":"$(json_escape "${MBR_FLEET_TRACKING_SECRET}")","platform_version":"$(json_escape "${MBR_FLEET_PLATFORM_VERSION:-}")","activity_bucket_30d":"${activity_bucket}","workspace_count":${workspace_count:-0},"extensions":${extensions_json:-[]}}
EOF
)"

curl \
  --fail \
  --silent \
  --show-error \
  --retry 2 \
  --retry-all-errors \
  --retry-delay 5 \
  --max-time 20 \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "${payload}" \
  "${MBR_FLEET_API_URL%/}/api/fleet/heartbeat" \
  >/dev/null
