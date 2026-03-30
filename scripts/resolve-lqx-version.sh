#!/usr/bin/env bash
# scripts/resolve-lqx-version.sh — resolve the latest Liquorix/Zen kernel version
#
# Queries the damentz/liquorix-package GitHub tags API and prints the most
# recent KERNEL_MAJOR-LQX_REL string matching the given kernel major version.
# Falls back to a hardcoded value if the API is unreachable.
#
# Usage:
#   ./scripts/resolve-lqx-version.sh [KERNEL_MAJOR]
#   KERNEL_MAJOR: e.g. "6.19" — if omitted, returns the overall latest tag.
#
# Output format: KERNEL_MAJOR-LQX_REL  (e.g. 6.19-6)

set -euo pipefail

FALLBACK_VERSION="6.19-6"
# Liquorix publishes tags only — no GitHub Releases
TAGS_API="https://api.github.com/repos/damentz/liquorix-package/tags?per_page=100"

KERNEL_MAJOR="${1:-}"

if ! command -v curl &>/dev/null; then
  echo "${FALLBACK_VERSION}"
  exit 0
fi

response=$(curl -sf --max-time 10 "${TAGS_API}" 2>/dev/null) || {
  echo "${FALLBACK_VERSION}"
  exit 0
}

# Extract all tags matching MAJOR-REL format, newest-first
if command -v jq &>/dev/null; then
  all_tags=$(echo "${response}" | jq -r '.[].name' 2>/dev/null \
    | grep -E '^[0-9]+\.[0-9]+-[0-9]+$') || true
else
  all_tags=$(echo "${response}" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 \
    | grep -E '^[0-9]+\.[0-9]+-[0-9]+$') || true
fi

tag=""
if [[ -n "${KERNEL_MAJOR}" ]]; then
  # Find latest tag for the requested kernel major (e.g. 6.18)
  tag=$(echo "${all_tags}" | grep -E "^${KERNEL_MAJOR}-[0-9]+$" | head -1) || true
fi

# Fall back to overall latest if no match for the requested major
if [[ -z "${tag}" ]]; then
  tag=$(echo "${all_tags}" | head -1) || true
fi

if [[ -n "${tag}" ]]; then
  echo "${tag}"
else
  echo "${FALLBACK_VERSION}"
fi
