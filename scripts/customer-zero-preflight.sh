#!/usr/bin/env bash
set -euo pipefail

# Exercise the public, no-source checkout path a new operator follows before a
# host is touched: resolve the latest release, verify its three OCI artifacts,
# materialize a realistic instance config, and execute the public CLI installer.
# This is intentionally safe to run on a laptop or CI runner; it performs no
# SSH, DNS, cloud, or production writes.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${MBR_CUSTOMER_ZERO_VERSION:-}"
INSTALL_URL="${MBR_INSTALL_URL:-https://movebigrocks.com/install.sh}"
CERTIFICATE_IDENTITY="https://github.com/MoveBigRocks/platform/.github/workflows/production.yml@refs/heads/main"
CERTIFICATE_ISSUER="https://token.actions.githubusercontent.com"

for command in curl jq ruby oras cosign; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "customer-zero preflight requires ${command}" >&2
    exit 1
  }
done

if [[ -z "${VERSION}" ]]; then
  VERSION=$(curl -fsSL https://api.github.com/repos/MoveBigRocks/releases/releases/latest | jq -r '.tag_name')
fi
[[ "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "invalid platform release version: ${VERSION}" >&2
  exit 1
}

tmp_dir=$(mktemp -d)
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

for artifact in services migrations manifest; do
  ref="ghcr.io/movebigrocks/mbr-${artifact}:${VERSION}"
  digest=$(oras manifest fetch --descriptor "${ref}" | jq -r '.digest')
  [[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "could not resolve an immutable digest for ${ref}" >&2
    exit 1
  }
  cosign verify \
    --certificate-identity "${CERTIFICATE_IDENTITY}" \
    --certificate-oidc-issuer "${CERTIFICATE_ISSUER}" \
    "${ref}" >/dev/null
  case "${artifact}" in
    services) services_digest="${digest}" ;;
    migrations) migrations_digest="${digest}" ;;
    manifest) manifest_digest="${digest}" ;;
  esac
  echo "verified ${ref}@${digest}"
done

export CUSTOMER_ZERO_VERSION="${VERSION}"
export CUSTOMER_ZERO_SERVICES_DIGEST="${services_digest}"
export CUSTOMER_ZERO_MIGRATIONS_DIGEST="${migrations_digest}"
export CUSTOMER_ZERO_MANIFEST_DIGEST="${manifest_digest}"
export CUSTOMER_ZERO_OUTPUT="${tmp_dir}/mbr.instance.yaml"

ruby -ryaml - "${REPO_ROOT}/mbr.instance.yaml" <<'RUBY'
config = YAML.load_file(ARGV.fetch(0))
config.fetch("metadata")["name"] = "customer-zero"
config.fetch("metadata")["instanceID"] = "00000000-0000-4000-8000-000000000001"
spec = config.fetch("spec")
spec.fetch("domain").merge!(
  "app" => "app.customer-zero.invalid",
  "admin" => "admin.customer-zero.invalid",
  "api" => "api.customer-zero.invalid",
  "cookie" => ".customer-zero.invalid",
)
release = spec.fetch("deployment").fetch("release").fetch("core")
version = ENV.fetch("CUSTOMER_ZERO_VERSION")
release.merge!(
  "version" => version,
  "servicesArtifact" => "ghcr.io/movebigrocks/mbr-services:#{version}",
  "migrationsArtifact" => "ghcr.io/movebigrocks/mbr-migrations:#{version}",
  "manifestArtifact" => "ghcr.io/movebigrocks/mbr-manifest:#{version}",
  "servicesDigest" => ENV.fetch("CUSTOMER_ZERO_SERVICES_DIGEST"),
  "migrationsDigest" => ENV.fetch("CUSTOMER_ZERO_MIGRATIONS_DIGEST"),
  "manifestDigest" => ENV.fetch("CUSTOMER_ZERO_MANIFEST_DIGEST"),
)
spec.fetch("deployment").fetch("linuxTarget")["host"] = "192.0.2.10"
spec.fetch("auth")["breakGlassAdminEmail"] = "owner@customer-zero.invalid"
spec.fetch("email").fetch("outbound").merge!(
  "provider" => "mock",
  "fromEmail" => "support@customer-zero.invalid",
)
spec.fetch("email").fetch("inbound").merge!("mode" => "none", "provider" => "none")
spec.fetch("storage").merge!(
  "provider" => "filesystem",
  "region" => "",
  "endpoint" => "",
  "attachmentsBucket" => "customer-zero-attachments",
)
spec.fetch("fleet").fetch("registration")["operatorEmail"] = "owner@customer-zero.invalid"
File.write(ENV.fetch("CUSTOMER_ZERO_OUTPUT"), YAML.dump(config).sub(/\A---\n/, ""))
RUBY

"${REPO_ROOT}/scripts/read-instance-config.sh" "${CUSTOMER_ZERO_OUTPUT}" > "${tmp_dir}/instance.env"
grep -qx "core_version=${VERSION}" "${tmp_dir}/instance.env"
grep -qx "require_cosign=true" "${tmp_dir}/instance.env"
grep -qx "services_digest=${services_digest}" "${tmp_dir}/instance.env"
echo "materialized instance config passed validation"

curl -fsSL "${INSTALL_URL}" -o "${tmp_dir}/install.sh"
MBR_VERSION="${VERSION}" MBR_INSTALL_DIR="${tmp_dir}/bin" sh "${tmp_dir}/install.sh"
"${tmp_dir}/bin/mbr" version --json | jq -e --arg version "${VERSION}" '.version == $version'
"${tmp_dir}/bin/mbr" spec export --json > "${tmp_dir}/cli-spec.json"
jq -e '
  [.commands[].path | join(" ")] as $commands |
  ($commands | index("health check")) != null and
  ($commands | index("auth login")) != null and
  ($commands | index("extensions verify")) != null and
  ($commands | index("fleet register")) != null
' "${tmp_dir}/cli-spec.json"

bash "${REPO_ROOT}/scripts/validate-extension-desired-state.sh" \
  "${REPO_ROOT}/extensions/desired-state.yaml"
echo "customer-zero preflight passed for ${VERSION}"
