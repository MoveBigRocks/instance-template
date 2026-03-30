#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-mbr.instance.yaml}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "instance config not found: ${CONFIG_FILE}" >&2
  exit 1
fi

ruby - "${CONFIG_FILE}" <<'RUBY'
require "yaml"
require "uri"

config = YAML.load_file(ARGV[0])

def fetch_required(node, path)
  current = node
  path.each do |key|
    unless current.is_a?(Hash) && current.key?(key)
      raise "missing required field #{path.join('.')}"
    end
    current = current[key]
  end

  if current.nil? || (current.respond_to?(:empty?) && current.empty?)
    raise "missing required field #{path.join('.')}"
  end

  current
end

def fetch_optional(node, path, default = "")
  current = node
  path.each do |key|
    return default unless current.is_a?(Hash) && current.key?(key)
    current = current[key]
  end
  current.nil? ? default : current
end

def assert_allowed(name, value, allowed)
  return if allowed.include?(value)
  raise "#{name} must be one of: #{allowed.join(', ')}"
end

def normalize_api_base_url(raw)
  value = raw.to_s.strip
  raise "spec.fleet.endpoint is required" if value.empty?

  uri = URI.parse(value)
  if uri.scheme.to_s.empty? || uri.host.to_s.empty?
    raise "spec.fleet.endpoint must include scheme and host"
  end

  host = uri.host
  case
  when ["localhost", "127.0.0.1", "::1"].include?(host)
    # keep local host as-is
  when host.start_with?("api.")
    # already normalized
  when host.start_with?("admin.")
    uri.host = "api." + host.sub(/\Aadmin\./, "")
  else
    uri.host = "api." + host
  end

  uri.path = ""
  uri.query = nil
  uri.fragment = nil
  uri.to_s.sub(%r{/\z}, "")
end

def emit(key, value)
  normalized = value.to_s.gsub(/\r?\n/, " ").strip
  puts "#{key}=#{normalized}"
end

metadata = fetch_required(config, %w[metadata])
spec = fetch_required(config, %w[spec])
domain = fetch_required(spec, %w[domain])
deployment = fetch_required(spec, %w[deployment])
linux_target = fetch_required(deployment, %w[linuxTarget])
release = fetch_required(deployment, %w[release core])
auth = fetch_required(spec, %w[auth])
email = fetch_required(spec, %w[email])
outbound = fetch_required(email, %w[outbound])
inbound = fetch_required(email, %w[inbound])
storage = fetch_required(spec, %w[storage])
fleet = fetch_required(spec, %w[fleet])
fleet_registration = fetch_required(fleet, %w[registration])
fleet_heartbeat = fetch_required(fleet, %w[heartbeat])

environment = fetch_required(spec, %w[environment])
app_domain = fetch_required(domain, %w[app])
admin_domain = fetch_required(domain, %w[admin])
api_domain = fetch_required(domain, %w[api])
cookie_domain = fetch_required(domain, %w[cookie])
deploy_host = fetch_required(linux_target, %w[host])
root_dir = fetch_required(linux_target, %w[rootDir])
core_version = fetch_required(release, %w[version])
services_artifact = fetch_optional(release, %w[servicesArtifact], fetch_optional(release, %w[apiArtifact]))
migrations_artifact = fetch_required(release, %w[migrationsArtifact])
manifest_artifact = fetch_required(release, %w[manifestArtifact])
break_glass_admin_email = fetch_required(auth, %w[breakGlassAdminEmail])
email_provider = fetch_required(outbound, %w[provider])
email_from_email = fetch_required(outbound, %w[fromEmail])
email_from_name = fetch_optional(outbound, %w[fromName], "Move Big Rocks")
inbound_mode = fetch_required(inbound, %w[mode])
inbound_provider = fetch_required(inbound, %w[provider])
storage_provider = fetch_required(storage, %w[provider])
storage_region = fetch_optional(storage, %w[region])
storage_endpoint = fetch_optional(storage, %w[endpoint])
attachments_bucket = fetch_required(storage, %w[attachmentsBucket])
smtp_host = fetch_optional(outbound, %w[smtp host])
smtp_port = fetch_optional(outbound, %w[smtp port], "587")
ses_region = fetch_optional(outbound, %w[ses region])
fleet_endpoint = fetch_required(fleet, %w[endpoint])
fleet_operator_email = fetch_required(fleet_registration, %w[operatorEmail])
fleet_use_case = fetch_required(fleet_registration, %w[useCase])
fleet_registration_source = fetch_optional(fleet_registration, %w[source], "self_hosted")
fleet_heartbeat_enabled = fetch_required(fleet_heartbeat, %w[enabled])
fleet_api_url = normalize_api_base_url(fleet_endpoint)

raise "spec.deployment.release.core.servicesArtifact is required" if services_artifact.to_s.empty?
raise "spec.deployment.linuxTarget.host must not include a user prefix" if deploy_host.include?("@")
raise "spec.deployment.linuxTarget.rootDir must currently be /opt/mbr" unless root_dir == "/opt/mbr"

assert_allowed("spec.email.outbound.provider", email_provider, %w[postmark smtp ses mock none])
assert_allowed("spec.email.inbound.mode", inbound_mode, %w[webhook none])
assert_allowed("spec.email.inbound.provider", inbound_provider, %w[postmark ses none])
assert_allowed("spec.storage.provider", storage_provider, %w[s3-compatible filesystem])
assert_allowed("spec.fleet.registration.useCase", fleet_use_case, %w[internal_ops startup client_deployment personal other])
assert_allowed("spec.fleet.registration.source", fleet_registration_source, %w[self_hosted managed])

if storage_provider == "s3-compatible" && storage_region.to_s.empty?
  raise "spec.storage.region is required when using s3-compatible storage"
end

if email_provider == "smtp"
  raise "spec.email.outbound.smtp.host is required when using SMTP" if smtp_host.to_s.empty?
  raise "spec.email.outbound.smtp.port must be greater than zero when using SMTP" unless smtp_port.to_i.positive?
end

if email_provider == "ses" && ses_region.to_s.empty?
  raise "spec.email.outbound.ses.region is required when using SES"
end

emit("metadata_name", fetch_required(metadata, %w[name]))
emit("instance_id", fetch_required(metadata, %w[instanceID]))
emit("environment", environment)
emit("app_domain", app_domain)
emit("admin_domain", admin_domain)
emit("api_domain", api_domain)
emit("cookie_domain", cookie_domain)
emit("deploy_host", deploy_host)
emit("root_dir", root_dir)
emit("core_version", core_version)
emit("services_artifact", services_artifact)
emit("migrations_artifact", migrations_artifact)
emit("manifest_artifact", manifest_artifact)
emit("break_glass_admin_email", break_glass_admin_email)
emit("email_provider", email_provider)
emit("email_from_email", email_from_email)
emit("email_from_name", email_from_name)
emit("inbound_mode", inbound_mode)
emit("inbound_provider", inbound_provider)
emit("storage_provider", storage_provider)
emit("storage_region", storage_region)
emit("storage_endpoint", storage_endpoint)
emit("attachments_bucket", attachments_bucket)
emit("smtp_host", smtp_host)
emit("smtp_port", smtp_port)
emit("ses_region", ses_region)
emit("fleet_endpoint", fleet_endpoint)
emit("fleet_api_url", fleet_api_url)
emit("fleet_operator_email", fleet_operator_email)
emit("fleet_use_case", fleet_use_case)
emit("fleet_registration_source", fleet_registration_source)
emit("fleet_heartbeat_enabled", fleet_heartbeat_enabled)
RUBY
