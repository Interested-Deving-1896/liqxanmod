#!/usr/bin/env bash
# packaging/generic/install.sh — fallback: make install + auto-detect initramfs tool
set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?}"
KARCH="${KARCH:?}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
source "${SCRIPTS_DIR}/lib/log.sh"

log WARN "Using generic installer — distro-specific packaging not available."

cd "${KERNEL_SRC}"
make ARCH="${KARCH}" modules_install
make ARCH="${KARCH}" install

# Auto-detect initramfs tool
if   command -v update-initramfs &>/dev/null; then update-initramfs -u -k all
elif command -v dracut            &>/dev/null; then dracut --force
elif command -v mkinitcpio        &>/dev/null; then mkinitcpio -P
elif command -v genkernel         &>/dev/null; then genkernel initramfs
elif command -v mkinitfs          &>/dev/null; then mkinitfs  # Alpine
else log WARN "No initramfs tool found — update manually."
fi

# Auto-detect bootloader
if   command -v update-grub      &>/dev/null; then update-grub
elif command -v grub-mkconfig    &>/dev/null; then grub-mkconfig -o /boot/grub/grub.cfg
elif command -v grub2-mkconfig   &>/dev/null; then grub2-mkconfig -o /boot/grub2/grub.cfg
elif command -v update-extlinux  &>/dev/null; then update-extlinux  # Alpine
elif command -v lilo              &>/dev/null; then lilo
else log WARN "No bootloader updater found — update manually."
fi

log INFO "Generic install complete."
