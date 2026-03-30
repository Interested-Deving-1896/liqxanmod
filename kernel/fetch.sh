#!/usr/bin/env bash
# kernel/fetch.sh — fetch or update the XanMod kernel source tree
#
# Usage:
#   ./kernel/fetch.sh [BRANCH]
#
# BRANCH values (maps to gitlab.com/xanmod/linux branches):
#   MAIN — latest stable release (default)
#   EDGE — latest mainline with experimental patches
#   LTS  — long-term support
#   RT   — PREEMPT_RT real-time variant
#
# The source tree is cloned/updated into kernel/src/.
# Shallow clone (--depth 1) is used by default; set FULL_CLONE=1 for full history.
#
# Set XANMOD_NO_API=1 to skip the GitLab API version resolution and use
# the hardcoded fallbacks below.

set -euo pipefail

REPO_URL="https://gitlab.com/xanmod/linux.git"
GITLAB_API="https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/branches"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"

# ── Hardcoded fallbacks ───────────────────────────────────────────────────────
# Update when XanMod cuts a new release series.
declare -A BRANCH_FALLBACK=(
  [MAIN]="6.19"
  [EDGE]="6.19"
  [LTS]="6.12"
  [RT]="6.18-rt"
)

# ── Resolve branch versions from GitLab API ───────────────────────────────────
resolve_branch_versions() {
  if [[ "${XANMOD_NO_API:-0}" == "1" ]]; then
    echo "  (API disabled, using hardcoded fallbacks)"
    return
  fi
  if ! command -v curl &>/dev/null; then
    echo "  (curl not found, using hardcoded fallbacks)"
    return
  fi

  local api_response
  api_response=$(curl -sf --max-time 10 \
    "${GITLAB_API}?per_page=100" 2>/dev/null) || {
    echo "  (GitLab API unreachable, using hardcoded fallbacks)"
    return
  }

  local branches
  if command -v jq &>/dev/null; then
    branches=$(echo "${api_response}" | jq -r '.[].name' 2>/dev/null)
  else
    branches=$(echo "${api_response}" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  fi

  [[ -z "${branches}" ]] && { echo "  (Could not parse API response, using fallbacks)"; return; }

  local main_ver
  main_ver=$(echo "${branches}" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1)
  [[ -n "${main_ver}" ]] && BRANCH_MAP[MAIN]="${main_ver}" && BRANCH_MAP[EDGE]="${main_ver}"

  local lts_ver
  lts_ver=$(echo "${branches}" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -2 | head -1)
  [[ -n "${lts_ver}" && "${lts_ver}" != "${main_ver}" ]] && BRANCH_MAP[LTS]="${lts_ver}"

  local rt_ver
  rt_ver=$(echo "${branches}" | grep -E '^[0-9]+\.[0-9]+-rt$' | sort -V | tail -1)
  [[ -n "${rt_ver}" ]] && BRANCH_MAP[RT]="${rt_ver}"
}

declare -A BRANCH_MAP
for k in "${!BRANCH_FALLBACK[@]}"; do BRANCH_MAP[$k]="${BRANCH_FALLBACK[$k]}"; done

echo "==> Resolving XanMod branch versions..."
resolve_branch_versions

BRANCH="${1:-MAIN}"
BRANCH="${BRANCH^^}"

[[ -z "${BRANCH_MAP[$BRANCH]+_}" ]] && {
  echo "ERROR: Unknown branch '${BRANCH}'. Valid: ${!BRANCH_MAP[*]}" >&2
  exit 1
}

GIT_BRANCH="${BRANCH_MAP[$BRANCH]}"
DEPTH_ARGS=("--depth" "1")
[[ "${FULL_CLONE:-0}" == "1" ]] && DEPTH_ARGS=()

echo "==> XanMod kernel fetch"
echo "    Branch : ${BRANCH} (git: ${GIT_BRANCH})"
echo "    Target : ${SRC_DIR}"
echo "    Source : ${REPO_URL}"
echo ""

if [[ -d "${SRC_DIR}/.git" ]]; then
  echo "==> Existing tree found — updating"
  cd "${SRC_DIR}"
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${CURRENT_BRANCH}" != "${GIT_BRANCH}" ]]; then
    echo "    Switching from '${CURRENT_BRANCH}' to '${GIT_BRANCH}'"
    git fetch "${DEPTH_ARGS[@]}" origin "${GIT_BRANCH}"
    git checkout "${GIT_BRANCH}"
  fi
  git pull "${DEPTH_ARGS[@]}" origin "${GIT_BRANCH}"
else
  echo "==> Cloning (this will take a while for a full clone)"
  git clone "${DEPTH_ARGS[@]}" \
    --branch "${GIT_BRANCH}" \
    --single-branch \
    "${REPO_URL}" \
    "${SRC_DIR}"
fi

KERNEL_VERSION=$(make -s -C "${SRC_DIR}" kernelversion 2>/dev/null || echo "unknown")
echo ""
echo "==> Done. Kernel version: ${KERNEL_VERSION}"
echo "    Source tree: ${SRC_DIR}"
