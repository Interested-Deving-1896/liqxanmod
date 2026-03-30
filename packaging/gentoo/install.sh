#!/usr/bin/env bash
# packaging/gentoo/install.sh — install via genkernel
set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?}"
KARCH="${KARCH:?}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
source "${SCRIPTS_DIR}/lib/log.sh"

KERNEL_VERSION="$(make -s -C "${KERNEL_SRC}" kernelversion 2>/dev/null)"

log INFO "Installing kernel modules"
make -C "${KERNEL_SRC}" ARCH="${KARCH}" modules_install

log INFO "Installing kernel image"
make -C "${KERNEL_SRC}" ARCH="${KARCH}" install

log INFO "Rebuilding initramfs via genkernel"
genkernel --kernel-config="${KERNEL_SRC}/.config" initramfs

log INFO "Updating GRUB"
grub-mkconfig -o /boot/grub/grub.cfg

log INFO "Gentoo install complete. Kernel: ${KERNEL_VERSION}-liqxanmod"
