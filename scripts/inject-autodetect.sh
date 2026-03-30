#!/usr/bin/env bash
# scripts/inject-autodetect.sh — copy the autodetect module into the kernel tree
#
# Called by build.sh when MODE=hybrid or MODE=auto.
# Copies kernel/liqxanmod_autodetect.c into the kernel source tree under
# drivers/liqxanmod/ and wires it into the Kconfig/Makefile build system.
#
# Usage:
#   ./scripts/inject-autodetect.sh KERNEL_SRC

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
KERNEL_SRC="${1:?KERNEL_SRC path required}"

# shellcheck source=lib/log.sh
source "${SCRIPTS_DIR}/lib/log.sh"

DEST_DIR="${KERNEL_SRC}/drivers/liqxanmod"
mkdir -p "${DEST_DIR}"

# ── Copy module source ────────────────────────────────────────────────────────
log INFO "Injecting autodetect module into ${DEST_DIR}"
cp "${REPO_ROOT}/kernel/liqxanmod_autodetect.c" "${DEST_DIR}/autodetect.c"

# ── Write Makefile ────────────────────────────────────────────────────────────
cat > "${DEST_DIR}/Makefile" << 'EOF'
# SPDX-License-Identifier: GPL-2.0
obj-$(CONFIG_LIQXANMOD_HYBRID) += autodetect.o
EOF

# ── Write Kconfig ─────────────────────────────────────────────────────────────
cat > "${DEST_DIR}/Kconfig" << 'EOF'
# SPDX-License-Identifier: GPL-2.0
# LiqXanMod autodetect driver — Kconfig stub.
# The main CONFIG_LIQXANMOD_HYBRID symbol is defined in kernel/sched/Kconfig.
# This file exists so drivers/Kconfig can source it.
EOF

# ── Hook into drivers/Kconfig if not already present ─────────────────────────
DRIVERS_KCONFIG="${KERNEL_SRC}/drivers/Kconfig"
if ! grep -q 'liqxanmod' "${DRIVERS_KCONFIG}" 2>/dev/null; then
  log INFO "Hooking into drivers/Kconfig"
  # Insert before the final 'endmenu'
  sed -i '/^endmenu/i source "drivers/liqxanmod/Kconfig"' "${DRIVERS_KCONFIG}"
fi

# ── Hook into drivers/Makefile if not already present ────────────────────────
DRIVERS_MAKEFILE="${KERNEL_SRC}/drivers/Makefile"
if ! grep -q 'liqxanmod' "${DRIVERS_MAKEFILE}" 2>/dev/null; then
  log INFO "Hooking into drivers/Makefile"
  echo 'obj-$(CONFIG_LIQXANMOD_HYBRID) += liqxanmod/' >> "${DRIVERS_MAKEFILE}"
fi

log INFO "Autodetect module injected."
