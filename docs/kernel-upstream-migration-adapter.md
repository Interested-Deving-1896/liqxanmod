# LiqXanMod KUMBE provider adapter

This document records the actual LiqXanMod source and patch boundaries that a future KUMBE adapter must inventory. It is a read-only integration contract, not an implementation of migration or patch application.

## Provider identity

LiqXanMod is a hybrid product. It must not be collapsed into a generic XanMod adapter: it combines a selected XanMod kernel source line with independently selected Liquorix/Zen patch sets and LiqXanMod hybrid glue.

- Source resolver: `kernel/fetch.sh`, targeting `https://gitlab.com/xanmod/linux.git`.
- Build/profile orchestration: `build.sh`, including `MODE`, `BRANCH`, and optional `LQX_VER`.
- Patch application: `scripts/apply-patches.sh`.
- Patch series: `patches/core`, `patches/liquorix/zen`, `patches/liquorix/lqx`, `patches/hybrid`, and conditional XanMod scheduler/filesystem/network/boot/hardware series.
- Config inputs: `configs/base`, `configs/arch`, `configs/features`, and `configs/hardware`.

## Adapter requirements

1. Record the selected `MODE`, exact requested `BRANCH`, resolved upstream branch/ref, and immutable source commit. MAIN/EDGE/LTS/RT are labels, not commit identities.
2. Record Liquorix/Zen patch origin and version separately from the XanMod source commit. Do not infer a single upstream provenance for the hybrid result.
3. Inventory every enabled series in the exact order used by `scripts/apply-patches.sh`; preserve disabled series as disabled, not silently omitted.
4. Record config fragments and hardware/workload profile inputs independently.
5. Produce read-only discovery and dry-run plans before any patch application. The adapter must not invoke `build.sh` or `scripts/apply-patches.sh` as part of discovery.
6. Require explicit approval before any semantic/manual port, security-sensitive change, ABI/config change, or isolated apply.

## Existing safety concern to resolve before apply integration

The current `scripts/apply-patches.sh` warns and skips missing patch files. It also treats an unsuccessful `patch` invocation without newly-created `.rej` files as “already applied”. Those heuristics are not sufficient evidence that a patch is present or safe to skip. KUMBE must independently verify patch identity/application state and block ambiguous outcomes; it must not reuse those assumptions as successful validation.

## Initial adapter stages

- **Stage 0 — inventory:** source URL/ref/commit/version, selected mode/branch, config fragments, patch-series order, patch hashes, missing files, and provenance gaps.
- **Stage 1 — dry run:** dependency and applicability plan; no source-tree mutation.
- **Stage 2 — isolated apply:** disposable worktree and explicit patch-state checks.
- **Stage 3 — validation:** config resolution, architecture/toolchain build, module compatibility, and boot/runtime evidence where available.

No kernel source or patch is changed by this documentation.
## KUMBE manifest v1.1 mapping

Emit distinct `source_inputs` records; never synthesize one combined source identity:

- `kernel-source`: XanMod GitLab repository, selected lane/ref, and resolved full commit.
- `liquorix-zen-patches`: independently versioned Liquorix/Zen patch origin and immutable commit or archive digest.
- `provider-patches`: LiqXanMod core/hybrid patch queue, with its own immutable repository commit or archive digest.
- `config-bundle`: selected base, architecture, feature, and hardware config inputs, pinned independently when they originate outside the provider commit.

Use `integrity: verified` only when the adapter has checked the declared identity against the available trusted evidence. Otherwise preserve `unverified` or `unavailable`; the BDFS planner blocks those inputs. The planner does not itself verify signatures or hashes.
