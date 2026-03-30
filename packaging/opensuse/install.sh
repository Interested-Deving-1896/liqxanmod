#!/usr/bin/env bash
# packaging/opensuse/install.sh — build RPM and install via zypper
set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?}"
KARCH="${KARCH:?}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
source "${SCRIPTS_DIR}/lib/log.sh"

cd "${KERNEL_SRC}"
log INFO "Building RPM package"
make -j"${JOBS:-$(nproc)}" ARCH="${KARCH}" rpm-pkg

RPM="$(ls -t "${HOME}"/rpmbuild/RPMS/x86_64/kernel-liqxanmod-*.rpm 2>/dev/null | head -1)"
[[ -z "${RPM}" ]] && { log ERROR "No RPM found"; exit 1; }

log INFO "Installing ${RPM}"
zypper --non-interactive install "${RPM}"

log INFO "Rebuilding initramfs"
dracut --force

log INFO "Updating bootloader"
grub2-mkconfig -o /boot/grub2/grub.cfg
