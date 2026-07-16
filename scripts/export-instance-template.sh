#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
if [[ -z "${target}" || "${target}" != /* ]]; then
  echo "usage: $0 /absolute/path/to/new-instance-repo" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

if [[ -e "${target}" ]] && [[ -n "$(find "${target}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "refusing to export into non-empty target: ${target}" >&2
  exit 1
fi

mkdir -p "${target}"
git -C "${repo_root}" archive --format=tar HEAD | tar -xf - -C "${target}"

echo "Exported the tracked instance template to ${target}"
echo "Next: initialise a private git repo, fill in mbr.instance.yaml, and follow START_HERE.md."
