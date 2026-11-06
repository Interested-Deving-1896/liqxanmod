## Current status

This repository does not currently contain a verified Nitrux Aesthetic FHS kernel implementation or `CONFIG_NITRUX_AESTHETIC_FHS` integration. The upstream `aesthetic-fhs` repository inspected for this work contains the userspace `afhs` controller and its Generic Netlink client ABI declarations, not the kernel-side family implementation.

## Required design

- Keep the hybrid XanMod/Liquorix/Zen defaults unchanged.
- Do not add a config-only `CONFIG_NITRUX_AESTHETIC_FHS=y` fragment: that would not implement the Generic Netlink family.
- Add an opt-in feature only after an authoritative kernel patch/source tree is available, reviewed, and shown to build against each supported kernel base.
- Verify the `aesthetic_fhs` Generic Netlink family, command/attribute ABI, permission model, and runtime behavior before packaging `afhs`.
- Treat `nitrux-standard` as optional userspace metadata/profile input, not a kernel build dependency. Resolve its `afhs` dependency per distro release and architecture.
- Preserve upstream provenance and per-file license notices; do not vendor the userspace controller until its BSD repository license and GPL-2.0 file identifiers are reconciled.

## Acceptance gates

1. Obtain and pin the kernel-side implementation.
2. Review patch applicability and licensing.
3. Build all supported architecture/profile combinations with the feature both off and on.
4. Boot-test and verify Generic Netlink discovery and `afhs` operations.
5. Verify graceful fallback on kernels without the family.

Upstream references: https://github.com/Nitrux/aesthetic-fhs and https://github.com/Nitrux/nitrux-standard

This document records a capability gate, not an assertion that the feature is implemented.