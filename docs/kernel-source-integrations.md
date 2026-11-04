# Kernel source integration map

This document records the upstream source relationships and the safe integration boundary for LiqXanMod.

## Source roles

| Project | Role | Integration policy |
|---|---|---|
| [torvalds/linux](https://github.com/torvalds/linux) | Canonical upstream Linux kernel source and baseline for version/ABI comparison | Reference and compatibility baseline. Do not silently replace the XanMod build source with mainline. |
| [Interested-Deving-1896/linux-merge](https://github.com/Interested-Deving-1896/linux-merge) | Downstream Linux integration tree containing subsystem/development branches | Optional integration candidate. Select an explicit, reviewed branch and pin its commit before any build consumes it. |
| [xanmod/linux](https://gitlab.com/xanmod/linux) | Current primary kernel source fetched by `kernel/fetch.sh` | Existing default source; preserve current behavior. |
| [damentz/liquorix-package](https://github.com/damentz/liquorix-package) | Existing Liquorix/Zen patch and packaging input | Preserve as the current Liquorix patch source; it is not interchangeable with a kernel source tree. |

## Safe integration contract

- Keep XanMod as the default source for the existing XanMod branch/profile workflow.
- Treat mainline Linux as the vanilla baseline for source comparison, patch-base validation, and future opt-in builds.
- Treat linux-merge as a separately versioned downstream integration candidate, never as an implicit replacement for mainline or XanMod.
- Any future source selector must require an explicit source ID and branch/ref, record the resolved commit SHA, and keep source-specific patch application isolated.
- Before enabling either new source for package builds, validate kernel version compatibility, required patch applicability, configuration compatibility, supported architectures, and reproducible source provenance.
- Do not merge entire source trees or auto-merge subsystem branches into the default kernel source.

## Current implementation status

This change records and links the source relationships only. The current fetch/build path remains unchanged: `kernel/fetch.sh` still fetches XanMod, and Liquorix/Zen patches remain sourced through the existing patch workflow. Mainline and linux-merge are not yet selectable build inputs.
