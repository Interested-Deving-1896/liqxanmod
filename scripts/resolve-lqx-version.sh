#!/usr/bin/env bash
# scripts/resolve-lqx-version.sh — resolve the latest Liquorix/Zen kernel version
#
# Queries the damentz/liquorix-package GitHub releases API and prints the
# most recent KERNEL_MAJOR-LQX_REL string (e.g. "6.12.1-1").
# Falls back to a hardcoded value if the API is unreachable.
#
# Output format: KERNEL_MAJOR-LQX_REL  (e.g. 6.12.1-1)

set -euo pipefail

FALLBACK_VERSION="6.12.1-1"
API_URL="https://api.github.com/repos/damentz/liquorix-package/releases/latest"

if ! command -v curl &>/dev/null; then
  echo "${FALLBACK_VERSION}"
  exit 0
fi

response=$(curl -sf --max-time 10 "${API_URL}" 2>/dev/null) || {
  echo "${FALLBACK_VERSION}"
  exit 0
}

# Tag format is typically "MAJOR-REL" e.g. "6.12.1-1"
tag=""
if command -v jq &>/dev/null; then
  tag=$(echo "${response}" | jq -r '.tag_name // empty' 2>/dev/null)
else
  tag=$(echo "${response}" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
fi

if [[ -n "${tag}" ]]; then
  echo "${tag}"
else
  echo "${FALLBACK_VERSION}"
fi
