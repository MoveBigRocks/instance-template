.PHONY: validate-instance-template customer-zero

validate-instance-template:
	@find scripts deploy -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	@scripts/read-instance-config.sh mbr.instance.yaml >/dev/null
	@bash scripts/validate-extension-desired-state.sh extensions/desired-state.yaml
	@if command -v actionlint >/dev/null 2>&1; then actionlint -shellcheck= .github/workflows/*.yml; else echo "actionlint not installed; workflow syntax is checked in CI"; fi

customer-zero:
	@bash scripts/customer-zero-preflight.sh
