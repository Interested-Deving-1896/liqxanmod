#!/usr/bin/env bash
# packaging/debian/install.sh — build .deb packages and install them
# Handles deepin immutable root automatically.
set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?}"
KARCH="${KARCH:?}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
source "${SCRIPTS_DIR}/lib/log.sh"

# deepin immutable root workaround
DEEPIN_WRITABLE=0
if command -v deepin-immutable-writable &>/dev/null; then
  log INFO "deepin: enabling writable root"
  deepin-immutable-writable enable
  DEEPIN_WRITABLE=1
fi

restore_deepin() {
  if [[ "${DEEPIN_WRITABLE}" == "1" ]]; then
    log INFO "deepin: restoring immutable root"
    deepin-immutable-writable disable || true
  fi
}
trap restore_deepin EXIT

cd "${KERNEL_SRC}"
log INFO "Building .deb packages"
make -j"${JOBS:-$(nproc)}" ARCH="${KARCH}" bindeb-pkg

DEB_DIR="$(dirname "${KERNEL_SRC}")"
log INFO "Installing packages from ${DEB_DIR}"
# shellcheck disable=SC2012
dpkg -i "$(ls -t "${DEB_DIR}"/../linux-image-*.deb 2>/dev/null | head -1)" || true
dpkg -i "$(ls -t "${DEB_DIR}"/../linux-headers-*.deb 2>/dev/null | head -1)" || true

log INFO "Updating initramfs"
update-initramfs -u -k all

log INFO "Updating bootloader"
if command -v update-grub &>/dev/null; then
  update-grub
elif command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
fi
