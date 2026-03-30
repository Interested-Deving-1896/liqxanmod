#!/usr/bin/env bash
# packaging/arch/install.sh — build and install a pacman package
set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?}"
KARCH="${KARCH:?}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
source "${SCRIPTS_DIR}/lib/log.sh"

cd "${KERNEL_SRC}"
log INFO "Building pacman package"
make -j"${JOBS:-$(nproc)}" ARCH="${KARCH}" pacman-pkg

PKG="$(ls -t "${KERNEL_SRC}"/../linux-liqxanmod-*.pkg.tar.zst 2>/dev/null | head -1)"
if [[ -z "${PKG}" ]]; then
  log ERROR "No pacman package found after build"
  exit 1
fi

log INFO "Installing ${PKG}"
pacman -U --noconfirm "${PKG}"

log INFO "Rebuilding initramfs"
mkinitcpio -P

log INFO "Updating GRUB"
grub-mkconfig -o /boot/grub/grub.cfg
