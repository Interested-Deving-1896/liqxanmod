# Contributing

## What belongs here

- **Hybrid glue patches** (`patches/hybrid/`) — conflict resolution between
  XanMod and Zen patch sets. Each patch must document the conflict it resolves
  in `patches/hybrid/series` and `docs/hybrid-design.md`.

- **New profiles** (`profiles/`) — named build configurations for specific
  hardware or use cases.

- **Build system fixes** — improvements to `build.sh`, `Makefile`, or scripts
  under `scripts/`.

- **Autodetect tuning** — changes to classification thresholds or the
  hysteresis logic in `kernel/liqxanmod_autodetect.c`.

## What does not belong here

- Copies of XanMod or Zen/Liquorix patches. Those are fetched from upstream
  at build time. Patch content belongs in the upstream projects.

- Kernel `.config` files generated from a specific machine. Use config
  fragments under `configs/` instead.

## Patch submission checklist

- [ ] `shellcheck` passes: `make shellcheck`
- [ ] New patches have a `Subject:` header and explain the motivation
- [ ] Conflict resolution patches update the conflict map in `docs/hybrid-design.md`
- [ ] New series entries are appended to the correct `series` file
- [ ] `build.sh --no-install` completes without errors on x86-64

## Commit style

```
component: short description of what changed and why

Optional longer explanation if the motivation is non-obvious.
```

Examples:
```
patches/hybrid: deduplicate sched_nr_latency between XanMod and Zen
scripts/detect: add Void Linux detection via xbps-install
profiles: add steamdeck profile with ROG patches disabled
```
