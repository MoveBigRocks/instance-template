#!/usr/bin/env bash
set -euo pipefail

DESIRED_STATE_FILE="${1:-extensions/desired-state.yaml}"

if [[ ! -f "${DESIRED_STATE_FILE}" ]]; then
  echo "extension desired state not found: ${DESIRED_STATE_FILE}" >&2
  exit 1
fi

if ! command -v oras >/dev/null 2>&1; then
  echo "oras CLI not found in PATH" >&2
  exit 1
fi

entries_file="$(mktemp)"
trap 'rm -f "${entries_file}"' EXIT

ruby - "${DESIRED_STATE_FILE}" <<'RUBY' > "${entries_file}"
require "yaml"

doc = YAML.load_file(ARGV[0]) || {}
installed = doc.dig("extensions", "installed") || []

installed.each_with_index do |entry, index|
  raise "extensions.installed[#{index}] must be a mapping" unless entry.is_a?(Hash)

  slug = entry.fetch("slug", "").to_s.strip
  state = entry.fetch("state", "").to_s.strip.downcase
  source = entry.fetch("source", "").to_s.strip.downcase
  ref = entry.fetch("ref", "").to_s.strip
  scope = entry.fetch("scope", "").to_s.strip.downcase
  workspace = entry.fetch("workspace", "").to_s.strip

  state = "present" if state.empty?
  next if state == "absent"

  raise "extensions.installed[#{index}].slug is required" if slug.empty?
  raise "extensions.installed[#{index}].ref is required for installed entries" if ref.empty?

  if scope == "workspace" && workspace.empty?
    raise "extensions.installed[#{index}].workspace is required for workspace-scoped entries"
  end

  if source.empty? || source == "oci"
    if ref.end_with?(":latest")
      raise "extensions.installed[#{index}].ref must pin an explicit version tag or digest, not :latest"
    end

    unless ref.include?("@sha256:") || ref.match?(/:[^\/]+$/)
      raise "extensions.installed[#{index}].ref must include a version tag or digest"
    end

    puts ["oci", slug, ref].join("\t")
  else
    puts ["skip", slug, source].join("\t")
  end
end
RUBY

if [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_TOKEN:-}" ]]; then
  while IFS=$'\t' read -r mode _slug ref_or_source; do
    [[ "${mode}" == "oci" ]] || continue
    registry_host="${ref_or_source%%/*}"
    [[ -n "${registry_host}" ]] || continue
    if [[ -z "${seen_hosts:-}" || ":${seen_hosts}:" != *":${registry_host}:"* ]]; then
      echo "Authenticating to ${registry_host}"
      oras login "${registry_host}" --username "${REGISTRY_USERNAME}" --password "${REGISTRY_TOKEN}" >/dev/null
      seen_hosts="${seen_hosts:+${seen_hosts}:}${registry_host}"
    fi
  done < "${entries_file}"
fi

validated_count=0
while IFS=$'\t' read -r mode slug ref_or_source; do
  case "${mode}" in
    oci)
      validated_count=$((validated_count + 1))
      echo "Checking ${slug} -> ${ref_or_source}"
      oras manifest fetch --descriptor "${ref_or_source}" >/dev/null
      ;;
    skip)
      echo "Skipping non-OCI source validation for ${slug} (${ref_or_source})"
      ;;
  esac
done < "${entries_file}"

echo "Validated ${validated_count} installed extension refs from ${DESIRED_STATE_FILE}"
