## Current status

The kernel-side implementation is no longer considered unavailable: Nitrux publishes [patch 0009-aesthetic-fhs.patch](https://github.com/Nitrux/linux-kernel/blob/linux-nitrux/patches/0009-aesthetic-fhs.patch) in its `linux-nitrux` branch, and includes it in the patch series for a kernel source version identified as 7.3.1. This does not establish that the patch applies cleanly to the kernel bases supported here.

## Required design

- Keep the hybrid XanMod/Liquorix/Zen defaults unchanged.
- Do not add a config-only `CONFIG_NITRUX_AESTHETIC_FHS=y` fragment: the feature requires the kernel implementation, not just the Kconfig symbol.
- Review and pin the Nitrux kernel patch, then test its applicability against every supported kernel base/version before adding an opt-in build path.
- Review namespace and inode lifetime handling, directory enumeration hooks, Generic Netlink permissions, command/attribute ABI, and graceful behavior when the family is absent.
- Verify the `aesthetic_fhs` Generic Netlink family and runtime ABI before packaging/enabling `afhs`.
- Treat `nitrux-standard` as optional userspace metadata/profile input, not a kernel build dependency. Resolve its `afhs` dependency per distro release and architecture.
- Preserve upstream provenance and per-file license notices; do not vendor the userspace controller until its BSD-3-Clause repository license and GPL-2.0 source/header identifiers are reconciled.

## Acceptance gates

1. Pin the kernel patch and source version.
2. Review licensing, patch correctness, and applicability to all supported kernel bases.
3. Build supported architecture/profile combinations with the feature both off and on.
4. Boot-test Generic Netlink family discovery and `afhs` operations.
5. Verify graceful fallback on kernels without the family.

Upstream references: https://github.com/Nitrux/aesthetic-fhs ; https://github.com/Nitrux/nitrux-standard ; https://github.com/Nitrux/linux-kernel/blob/linux-nitrux/patches/0009-aesthetic-fhs.patch

Documentation only; no runtime support is claimed.