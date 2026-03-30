#!/usr/bin/env bash
# build.sh — LiqXanMod hybrid kernel build driver
#
# Merges XanMod (performance/throughput) and Liquorix/Zen (low-latency/RT)
# patch sets into a single kernel image. A runtime workload detector
# (kernel/liqxanmod_autodetect.c) is compiled in and selects scheduler
# behaviour and latency tuning at boot without requiring a reboot.
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --mode       auto|xanmod|liquorix|hybrid   Patch blend mode (default: hybrid)
#   --branch     MAIN|EDGE|LTS|RT              XanMod source branch (default: MAIN)
#   --lqx-ver    VERSION                       Liquorix/Zen version (e.g. 6.12.1, default: auto)
#   --profile    NAME                          Load profiles/NAME.sh
#   --mlevel     v1|v2|v3|v4                   x86-64 microarch level (auto-detected)
#   --vendor     amd|intel                     CPU vendor config fragment
#   --jobs       N                             Parallel jobs (default: nproc)
#   --no-fetch   Skip kernel source fetch
#   --no-install Build only, do not install
#   --help       Show this message
#
# Feature flags (env vars or set in profile):
#   ENABLE_ROG=1            ASUS ROG patches + config
#   ENABLE_MEDIATEK_BT=1    MediaTek MT7921 BT patches
#   ENABLE_FS_PATCHES=1     XanMod filesystem patches
#   ENABLE_NET_PATCHES=1    XanMod network patches
#   ENABLE_CACHY=1          CachyOS scheduler patch (XanMod side)
#   ENABLE_PARALLEL_BOOT=1  Parallel boot patch
#   ENABLE_ZEN_PATCHES=1    Zen/Liquorix scheduler + latency patches
#   ENABLE_LQX_PATCHES=1    Liquorix-specific tuning patches
#   NO_DEBUG=1              Disable debug/tracing overhead
#   LZ4_SWAP=1              LZ4 compressed swap
#   VENDOR=amd|intel        CPU vendor config fragment
#   EXTRA_CONFIG=path       Additional .config fragment (highest priority)
#   FULL_CLONE=1            Full git clone instead of shallow
#   XANMOD_NO_API=1         Skip GitLab API version resolution

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="${REPO_ROOT}/kernel/src"
PATCHES_DIR="${REPO_ROOT}/patches"
CONFIGS_DIR="${REPO_ROOT}/configs"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
PACKAGING_DIR="${REPO_ROOT}/packaging"

# ── Defaults ─────────────────────────────────────────────────────────────────
MODE="${MODE:-hybrid}"
BRANCH="${BRANCH:-MAIN}"
LQX_VER="${LQX_VER:-}"
PROFILE="${PROFILE:-}"
JOBS="${JOBS:-$(nproc)}"
DO_FETCH="${DO_FETCH:-1}"
DO_INSTALL="${DO_INSTALL:-1}"
MLEVEL="${MLEVEL:-}"
VENDOR="${VENDOR:-}"

ENABLE_ROG="${ENABLE_ROG:-0}"
ENABLE_MEDIATEK_BT="${ENABLE_MEDIATEK_BT:-0}"
ENABLE_FS_PATCHES="${ENABLE_FS_PATCHES:-0}"
ENABLE_NET_PATCHES="${ENABLE_NET_PATCHES:-0}"
ENABLE_CACHY="${ENABLE_CACHY:-0}"
ENABLE_PARALLEL_BOOT="${ENABLE_PARALLEL_BOOT:-0}"
ENABLE_ZEN_PATCHES="${ENABLE_ZEN_PATCHES:-1}"
ENABLE_LQX_PATCHES="${ENABLE_LQX_PATCHES:-1}"
NO_DEBUG="${NO_DEBUG:-0}"
LZ4_SWAP="${LZ4_SWAP:-0}"
EXTRA_CONFIG="${EXTRA_CONFIG:-}"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)        MODE="${2:?--mode requires a value}";    shift 2 ;;
    --branch)      BRANCH="${2:?--branch requires a value}"; shift 2 ;;
    --lqx-ver)     LQX_VER="${2:?--lqx-ver requires a value}"; shift 2 ;;
    --profile)     PROFILE="${2:?--profile requires a value}"; shift 2 ;;
    --mlevel)      MLEVEL="${2:?--mlevel requires a value}"; shift 2 ;;
    --vendor)      VENDOR="${2:?--vendor requires a value}"; shift 2 ;;
    --jobs)        JOBS="${2:?--jobs requires a value}";    shift 2 ;;
    --no-fetch)    DO_FETCH=0;    shift ;;
    --no-install)  DO_INSTALL=0;  shift ;;
    --help)
      sed -n '/^# Usage:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Load profile ──────────────────────────────────────────────────────────────
if [[ -n "${PROFILE}" ]]; then
  PROFILE_FILE="${REPO_ROOT}/profiles/${PROFILE}.sh"
  [[ -f "${PROFILE_FILE}" ]] || { echo "ERROR: Profile not found: ${PROFILE_FILE}" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "${PROFILE_FILE}"
  echo "==> Loaded profile: ${PROFILE}"
fi

# ── Validate mode ─────────────────────────────────────────────────────────────
case "${MODE}" in
  auto|xanmod|liquorix|hybrid) ;;
  *) echo "ERROR: Invalid --mode '${MODE}'. Valid: auto xanmod liquorix hybrid" >&2; exit 1 ;;
esac

# In 'xanmod' mode, disable Zen/Lqx patches; in 'liquorix' mode, disable XanMod extras
if [[ "${MODE}" == "xanmod" ]]; then
  ENABLE_ZEN_PATCHES=0
  ENABLE_LQX_PATCHES=0
elif [[ "${MODE}" == "liquorix" ]]; then
  ENABLE_CACHY=0
  ENABLE_FS_PATCHES=0
  ENABLE_NET_PATCHES=0
fi

# ── Source shared helpers ─────────────────────────────────────────────────────
# shellcheck source=scripts/lib/log.sh
source "${SCRIPTS_DIR}/lib/log.sh"
# shellcheck source=scripts/lib/detect.sh
source "${SCRIPTS_DIR}/lib/detect.sh"

# ── Detect host architecture ──────────────────────────────────────────────────
KARCH="$(detect_karch)"
export ARCH="${KARCH}"
export CROSS_COMPILE="${CROSS_COMPILE:-}"

# ── Detect x86-64 microarch level ────────────────────────────────────────────
[[ -z "${MLEVEL}" ]] && MLEVEL="$(detect_mlevel "${KARCH}")"

# ── Detect distro ────────────────────────────────────────────────────────────
DISTRO="${DISTRO:-$(detect_distro)}"
export DISTRO

# ── RT branch forces PREEMPT_RT ──────────────────────────────────────────────
[[ "${BRANCH}" == "RT" ]] && ENABLE_RT="${ENABLE_RT:-1}" || ENABLE_RT="${ENABLE_RT:-0}"

# ── Resolve Liquorix version ──────────────────────────────────────────────────
if [[ -z "${LQX_VER}" && ("${ENABLE_ZEN_PATCHES}" == "1" || "${ENABLE_LQX_PATCHES}" == "1") ]]; then
  LQX_VER="$("${SCRIPTS_DIR}/resolve-lqx-version.sh")"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> LiqXanMod Hybrid Kernel Build"
echo "    Mode    : ${MODE}"
echo "    Branch  : ${BRANCH}${LQX_VER:+ | Liquorix ${LQX_VER}}"
echo "    Arch    : ${KARCH}${MLEVEL:+ (x86-64-${MLEVEL})}"
echo "    Distro  : ${DISTRO}"
echo "    Jobs    : ${JOBS}"
[[ -n "${PROFILE}" ]] && echo "    Profile : ${PROFILE}"
[[ -n "${VENDOR}"  ]] && echo "    Vendor  : ${VENDOR}"
echo "    Patches :"
[[ "${ENABLE_ZEN_PATCHES}"    == "1" ]] && echo "      Zen/Liquorix scheduler + latency"
[[ "${ENABLE_LQX_PATCHES}"    == "1" ]] && echo "      Liquorix tuning"
[[ "${ENABLE_CACHY}"          == "1" ]] && echo "      CachyOS scheduler (XanMod)"
[[ "${ENABLE_FS_PATCHES}"     == "1" ]] && echo "      Filesystem (XanMod)"
[[ "${ENABLE_NET_PATCHES}"    == "1" ]] && echo "      Network (XanMod)"
[[ "${ENABLE_ROG}"            == "1" ]] && echo "      ASUS ROG"
[[ "${ENABLE_MEDIATEK_BT}"    == "1" ]] && echo "      MediaTek BT"
[[ "${ENABLE_PARALLEL_BOOT}"  == "1" ]] && echo "      Parallel boot"
[[ "${ENABLE_RT}"             == "1" ]] && echo "      PREEMPT_RT"
[[ "${NO_DEBUG}"              == "1" ]] && echo "      No-debug"
[[ "${LZ4_SWAP}"              == "1" ]] && echo "      LZ4 swap"
[[ "${MODE}"                  == "auto" || "${MODE}" == "hybrid" ]] && \
  echo "      Runtime autodetect (liqxanmod_autodetect)"
echo ""

# ── Step 1: Fetch XanMod kernel source ───────────────────────────────────────
if [[ "${DO_FETCH}" == "1" ]]; then
  "${REPO_ROOT}/kernel/fetch.sh" "${BRANCH}"
fi

[[ -d "${KERNEL_SRC}" ]] || {
  echo "ERROR: Kernel source not found at ${KERNEL_SRC}" >&2
  echo "       Run without --no-fetch, or run kernel/fetch.sh first." >&2
  exit 1
}

# ── Step 2: Fetch Liquorix patch archive (if needed) ─────────────────────────
if [[ "${ENABLE_ZEN_PATCHES}" == "1" || "${ENABLE_LQX_PATCHES}" == "1" ]]; then
  "${SCRIPTS_DIR}/fetch-lqx-patches.sh" "${LQX_VER}"
fi

# ── Step 3: Apply patches ─────────────────────────────────────────────────────
export MODE ENABLE_ROG ENABLE_MEDIATEK_BT ENABLE_FS_PATCHES \
       ENABLE_NET_PATCHES ENABLE_CACHY ENABLE_PARALLEL_BOOT \
       ENABLE_ZEN_PATCHES ENABLE_LQX_PATCHES ENABLE_RT LQX_VER

"${SCRIPTS_DIR}/apply-patches.sh" "${KERNEL_SRC}" "${PATCHES_DIR}"

# ── Step 4: Inject runtime autodetect module source ──────────────────────────
if [[ "${MODE}" == "auto" || "${MODE}" == "hybrid" ]]; then
  "${SCRIPTS_DIR}/inject-autodetect.sh" "${KERNEL_SRC}"
fi

# ── Step 5: Merge config fragments ───────────────────────────────────────────
log INFO "Merging config fragments"
MERGE_SCRIPT="${KERNEL_SRC}/scripts/kconfig/merge_config.sh"
[[ -x "${MERGE_SCRIPT}" ]] || {
  echo "ERROR: merge_config.sh not found in kernel source." >&2; exit 1
}

FRAGMENTS=()

# Base: architecture + microarch level
if [[ "${KARCH}" == "x86" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/x86-64-${MLEVEL}.config")
elif [[ "${KARCH}" == "arm64" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/aarch64.config")
elif [[ "${KARCH}" == "riscv" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/riscv64.config")
fi

# CPU vendor fragment
if [[ -n "${VENDOR}" ]]; then
  VENDOR_CFG="${CONFIGS_DIR}/arch/${VENDOR}.config"
  [[ -f "${VENDOR_CFG}" ]] && FRAGMENTS+=("${VENDOR_CFG}") \
    || log WARN "No vendor config for '${VENDOR}', skipping."
fi

# Mode-specific config layer
case "${MODE}" in
  xanmod)   FRAGMENTS+=("${CONFIGS_DIR}/features/xanmod.config") ;;
  liquorix) FRAGMENTS+=("${CONFIGS_DIR}/features/liquorix.config") ;;
  hybrid|auto)
    FRAGMENTS+=("${CONFIGS_DIR}/features/xanmod.config")
    FRAGMENTS+=("${CONFIGS_DIR}/features/liquorix.config")
    FRAGMENTS+=("${CONFIGS_DIR}/features/hybrid.config")
    ;;
esac

# Optional feature fragments
[[ "${ENABLE_RT}"            == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/rt.config")
[[ "${LZ4_SWAP}"             == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/lz4-swap.config")
[[ "${NO_DEBUG}"             == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/no-debug.config")
[[ "${ENABLE_ROG}"           == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/hardware/asus-rog.config")

# User-supplied extra fragment (highest priority)
[[ -n "${EXTRA_CONFIG}" && -f "${EXTRA_CONFIG}" ]] && FRAGMENTS+=("${EXTRA_CONFIG}")

log INFO "Fragments:"
for f in "${FRAGMENTS[@]}"; do log INFO "  $(basename "${f}")"; done

cd "${KERNEL_SRC}"
"${MERGE_SCRIPT}" -m .config "${FRAGMENTS[@]}"
make -j"${JOBS}" ARCH="${KARCH}" olddefconfig

# ── Step 6: Build ─────────────────────────────────────────────────────────────
echo ""
log INFO "Building kernel (jobs: ${JOBS})"
time make -j"${JOBS}" ARCH="${KARCH}" ${CROSS_COMPILE:+CROSS_COMPILE="${CROSS_COMPILE}"}

# ── Step 7: Install ───────────────────────────────────────────────────────────
if [[ "${DO_INSTALL}" == "1" ]]; then
  echo ""
  log INFO "Installing via packaging/${DISTRO}/install.sh"
  INSTALLER="${PACKAGING_DIR}/${DISTRO}/install.sh"
  if [[ ! -x "${INSTALLER}" ]]; then
    log WARN "No installer for distro '${DISTRO}', falling back to generic."
    INSTALLER="${PACKAGING_DIR}/generic/install.sh"
  fi
  KERNEL_SRC="${KERNEL_SRC}" KARCH="${KARCH}" bash "${INSTALLER}"
fi

echo ""
log INFO "Build complete."
