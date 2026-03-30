#!/usr/bin/env bash
# scripts/apply-patches.sh — apply the LiqXanMod hybrid patch series
#
# Called by build.sh. Not intended for direct use.
#
# Arguments:
#   $1 — path to kernel source tree
#   $2 — path to patches/ directory (default: patches/ relative to repo root)
#
# Environment variables (set by build.sh or profile):
#   MODE                  hybrid|xanmod|liquorix|auto
#   ENABLE_ZEN_PATCHES=1  Apply Zen/Liquorix scheduler + latency patches
#   ENABLE_LQX_PATCHES=1  Apply Liquorix-specific tuning patches
#   ENABLE_ROG=1          Apply ASUS ROG hardware patches
#   ENABLE_MEDIATEK_BT=1  Apply MediaTek MT7921 BT patches
#   ENABLE_FS_PATCHES=1   Apply XanMod filesystem patches
#   ENABLE_NET_PATCHES=1  Apply XanMod network patches
#   ENABLE_CACHY=1        Apply CachyOS scheduler patch (XanMod side)
#   ENABLE_PARALLEL_BOOT=1 Apply parallel boot patch
#   ENABLE_RT=1           Apply PREEMPT_RT config (branch-level, not a patch)
#
# Patch application order (matters for conflict avoidance):
#   1. patches/core/           — unconditional base fixes
#   2. patches/liquorix/zen/   — Zen scheduler + latency (if ENABLE_ZEN_PATCHES)
#   3. patches/liquorix/lqx/   — Liquorix tuning (if ENABLE_LQX_PATCHES)
#   4. patches/hybrid/         — glue patches resolving XanMod↔Zen conflicts
#   5. patches/xanmod/sched/   — CachyOS scheduler (if ENABLE_CACHY, hybrid-safe)
#   6. patches/xanmod/fs/      — filesystem patches (if ENABLE_FS_PATCHES)
#   7. patches/xanmod/net/     — network patches (if ENABLE_NET_PATCHES)
#   8. patches/xanmod/boot/    — parallel boot (if ENABLE_PARALLEL_BOOT)
#   9. patches/xanmod/hardware/asus-rog/    (if ENABLE_ROG)
#  10. patches/xanmod/hardware/mediatek-bt/ (if ENABLE_MEDIATEK_BT)

set -euo pipefail

KERNEL_SRC="${1:?kernel source path required}"
PATCHES_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/log.sh
source "${SCRIPTS_DIR}/lib/log.sh"

MODE="${MODE:-hybrid}"

# ── apply_series ──────────────────────────────────────────────────────────────
# Apply all patches listed in a series file, relative to that file's directory.
# Skips missing patches with a warning rather than aborting.
apply_series() {
  local series_file="$1"
  local patch_dir
  patch_dir="$(dirname "${series_file}")"

  [[ -f "${series_file}" ]] || return 0

  local applied=0 skipped=0
  while IFS= read -r line; do
    # skip comments and blank lines
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    local patch_path="${patch_dir}/${line}"
    if [[ ! -f "${patch_path}" ]]; then
      log WARN "patch not found, skipping: ${patch_path}"
      (( skipped++ )) || true
      continue
    fi

    # Try to apply; on failure, attempt 3-way merge before aborting
    if ! patch -p1 --dry-run -d "${KERNEL_SRC}" < "${patch_path}" &>/dev/null; then
      log WARN "patch does not apply cleanly, attempting 3-way merge: ${line}"
      if ! patch -p1 --merge -d "${KERNEL_SRC}" < "${patch_path}"; then
        log ERROR "patch failed (conflict markers left in tree): ${line}"
        log ERROR "Resolve conflicts in ${KERNEL_SRC}, then re-run with --no-fetch."
        exit 1
      fi
    else
      patch -p1 -d "${KERNEL_SRC}" < "${patch_path}"
    fi
    (( applied++ )) || true
  done < "${series_file}"

  log INFO "  applied=${applied} skipped=${skipped}"
}

# ── apply_set ─────────────────────────────────────────────────────────────────
# Wrapper that logs the set name and calls apply_series.
apply_set() {
  local label="$1"
  local series_file="$2"
  log INFO "[${label}]"
  apply_series "${series_file}"
}

echo ""
log INFO "Applying LiqXanMod patch sets (mode: ${MODE})"

# 1. Core — always applied
apply_set "core" "${PATCHES_DIR}/core/series"

# 2. Zen scheduler + latency patches (Liquorix side)
if [[ "${ENABLE_ZEN_PATCHES:-1}" == "1" && "${MODE}" != "xanmod" ]]; then
  apply_set "liquorix/zen" "${PATCHES_DIR}/liquorix/zen/series"
fi

# 3. Liquorix tuning patches
if [[ "${ENABLE_LQX_PATCHES:-1}" == "1" && "${MODE}" != "xanmod" ]]; then
  apply_set "liquorix/lqx" "${PATCHES_DIR}/liquorix/lqx/series"
fi

# 4. Hybrid glue — resolves scheduler symbol conflicts between XanMod and Zen
#    Applied after Zen patches so it can reference Zen-introduced symbols.
if [[ "${MODE}" == "hybrid" || "${MODE}" == "auto" ]]; then
  apply_set "hybrid" "${PATCHES_DIR}/hybrid/series"
fi

# 5. CachyOS scheduler (XanMod side)
#    In hybrid mode this is applied after Zen so both schedulers are compiled
#    in; the autodetect module selects between them at runtime.
if [[ "${ENABLE_CACHY:-0}" == "1" && "${MODE}" != "liquorix" ]]; then
  apply_set "xanmod/sched" "${PATCHES_DIR}/xanmod/sched/series"
fi

# 6. Filesystem patches (XanMod)
if [[ "${ENABLE_FS_PATCHES:-0}" == "1" && "${MODE}" != "liquorix" ]]; then
  apply_set "xanmod/fs" "${PATCHES_DIR}/xanmod/fs/series"
fi

# 7. Network patches (XanMod)
if [[ "${ENABLE_NET_PATCHES:-0}" == "1" && "${MODE}" != "liquorix" ]]; then
  apply_set "xanmod/net" "${PATCHES_DIR}/xanmod/net/series"
fi

# 8. Parallel boot (XanMod)
if [[ "${ENABLE_PARALLEL_BOOT:-0}" == "1" ]]; then
  apply_set "xanmod/boot" "${PATCHES_DIR}/xanmod/boot/series"
fi

# 9. ASUS ROG hardware patches
if [[ "${ENABLE_ROG:-0}" == "1" ]]; then
  apply_set "xanmod/hardware/asus-rog" "${PATCHES_DIR}/xanmod/hardware/asus-rog/series"
fi

# 10. MediaTek BT patches
if [[ "${ENABLE_MEDIATEK_BT:-0}" == "1" ]]; then
  apply_set "xanmod/hardware/mediatek-bt" "${PATCHES_DIR}/xanmod/hardware/mediatek-bt/series"
fi

echo ""
log INFO "Patch application complete."
