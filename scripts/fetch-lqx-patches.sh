#!/usr/bin/env bash
# scripts/fetch-lqx-patches.sh — download and stage Liquorix/Zen patch series
#
# Downloads the liquorix-package archive for the given version and extracts
# the zen/ and lqx/ patch series into patches/liquorix/{zen,lqx}/.
#
# Usage:
#   ./scripts/fetch-lqx-patches.sh VERSION
#   VERSION format: KERNEL_MAJOR-LQX_REL  (e.g. 6.12.1-1)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
PATCHES_DIR="${REPO_ROOT}/patches/liquorix"
CACHE_DIR="${REPO_ROOT}/.cache/lqx"

# shellcheck source=lib/log.sh
source "${SCRIPTS_DIR}/lib/log.sh"

VERSION="${1:?VERSION required (e.g. 6.12.1-1)}"

# Split into KERNEL_MAJOR and LQX_REL
KERNEL_MAJOR="${VERSION%-*}"
LQX_REL="${VERSION##*-}"

ARCHIVE_URL="https://github.com/damentz/liquorix-package/archive/${KERNEL_MAJOR}-${LQX_REL}.tar.gz"
ARCHIVE_FILE="${CACHE_DIR}/liquorix-package-${KERNEL_MAJOR}-${LQX_REL}.tar.gz"
EXTRACT_DIR="${CACHE_DIR}/liquorix-package-${KERNEL_MAJOR}-${LQX_REL}"

mkdir -p "${CACHE_DIR}"

if [[ ! -f "${ARCHIVE_FILE}" ]]; then
  log INFO "Downloading liquorix-package ${VERSION}"
  curl -L --fail "${ARCHIVE_URL}" -o "${ARCHIVE_FILE}"
else
  log INFO "Using cached liquorix-package ${VERSION}"
fi

if [[ ! -d "${EXTRACT_DIR}" ]]; then
  log INFO "Extracting archive"
  tar -xf "${ARCHIVE_FILE}" -C "${CACHE_DIR}"
fi

PATCH_SRC="${EXTRACT_DIR}/linux-liquorix/debian/patches"

[[ -d "${PATCH_SRC}" ]] || {
  log ERROR "Patch directory not found in archive: ${PATCH_SRC}"
  exit 1
}

stage_patches() {
  local prefix="${1}"   # e.g. "zen" or "lqx"
  local dest="${PATCHES_DIR}/${prefix}"
  mkdir -p "${dest}"

  # grep exits 1 when no lines match; that is not an error here
  local entries
  entries=$(grep -P "^${prefix}/" "${PATCH_SRC}/series" 2>/dev/null) || true

  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    local src="${PATCH_SRC}/${p}"
    local fname
    fname=$(basename "${p}")
    local dst="${dest}/${fname}"
    [[ -f "${src}" ]] && cp "${src}" "${dst}"
  done <<< "${entries}"

  # Write series index (strip the prefix/ component)
  printf '%s\n' "${entries}" | sed "s|^${prefix}/||" \
    | grep -v '^$' > "${dest}/series" || true
}

# Stage zen/ patches
log INFO "Staging zen/ patches"
stage_patches zen

# Stage lqx/ patches
log INFO "Staging lqx/ patches"
stage_patches lqx

log INFO "Liquorix patches staged: zen=$(wc -l < "${PATCHES_DIR}/zen/series" 2>/dev/null || echo 0) lqx=$(wc -l < "${PATCHES_DIR}/lqx/series" 2>/dev/null || echo 0)"
