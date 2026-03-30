# Hybrid kernel design

## Goals

XanMod and Liquorix/Zen optimise for different workloads:

| Kernel | Primary goal | Scheduler tuning |
|--------|-------------|-----------------|
| XanMod | Throughput, compile, server | Wide CFS slices, high `sched_nr_latency` |
| Liquorix/Zen | Desktop responsiveness, audio, gaming | Narrow CFS slices, low wakeup granularity |

LiqXanMod compiles both patch sets into one image and selects between them at
runtime based on observed workload characteristics.

## Patch conflict map

Both patch sets touch overlapping files in `kernel/sched/`. The table below
documents every known conflict and how it is resolved by the hybrid glue
patches in `patches/hybrid/`.

| Symbol / file | XanMod change | Zen change | Resolution |
|---|---|---|---|
| `kernel/sched/fair.c` — `sysctl_sched_latency` | 10 ms | 4 ms | Both values stored; sysfs bridge switches between them |
| `kernel/sched/fair.c` — `sched_nr_latency` | 10 | 4 | Zen definition kept; XanMod duplicate removed by `0003-liqxanmod-dedup-sched-nr-latency.patch` |
| `kernel/sched/fair.c` — `sysctl_sched_min_granularity` | 1 ms | 0.3 ms | Both stored; sysfs bridge switches |
| `kernel/sched/fair.c` — `sysctl_sched_wakeup_granularity` | 1.5 ms | 0.5 ms | Both stored; sysfs bridge switches |
| `mm/page_alloc.c` — watermark tweaks | XanMod tweak | Zen tweak | Zen wins (lower latency for page faults) |
| `include/linux/sched/sysctl.h` — `sched_nr_latency` declaration | added | added | Deduplicated by glue patch |

## Config fragment merge order

Config fragments are merged in this order (later fragments override earlier):

```
configs/base/x86-64-{v1,v2,v3,v4}.config   arch baseline
configs/arch/{amd,intel}.config              vendor overrides
configs/features/xanmod.config               XanMod options
configs/features/liquorix.config             Zen/Liquorix options
configs/features/hybrid.config               conflict resolution + autodetect
configs/features/rt.config                   (if BRANCH=RT)
configs/features/lz4-swap.config             (if LZ4_SWAP=1)
configs/features/no-debug.config             (if NO_DEBUG=1)
configs/hardware/asus-rog.config             (if ENABLE_ROG=1)
EXTRA_CONFIG                                 user-supplied (highest priority)
```

`configs/features/hybrid.config` resolves the one preemption conflict:
`liquorix.config` sets `CONFIG_PREEMPT=y` while `xanmod.config` sets
`CONFIG_PREEMPT_VOLUNTARY=y`. The hybrid fragment re-asserts `CONFIG_PREEMPT=y`
because full preemption gives the best worst-case latency while remaining
acceptable for throughput workloads.

## Sysfs bridge architecture

```
kernel/sched/liqxanmod_sysfs.c
  ├── /sys/kernel/liqxanmod/active_profile   (rw)
  ├── /sys/kernel/liqxanmod/autodetect       (rw)
  └── lqxm_apply_profile(enum lqxm_profile)  (exported symbol)

drivers/liqxanmod/autodetect.c
  ├── kthread: lqxm_detect (100 ms interval)
  ├── classify() → LQXM_THROUGHPUT | LQXM_LATENCY | LQXM_BALANCED
  ├── hysteresis gate (5 ticks = 500 ms)
  └── calls lqxm_apply_profile() on stable classification
```

`liqxanmod_sysfs.c` is compiled into `kernel/sched/` (always built-in when
`CONFIG_LIQXANMOD_HYBRID=y`). `autodetect.c` is compiled into
`drivers/liqxanmod/` and initialised after the sysfs bridge via
`module_init` ordering.

## Adding a new conflict resolution patch

1. Identify the conflicting symbol and which patch set introduced it.
2. Create `patches/hybrid/NNNN-description.patch` that resolves the conflict.
3. Add the filename to `patches/hybrid/series`.
4. Update the conflict map table above.
5. If the resolution changes a sysfs-exposed tunable, update
   `kernel/sched/liqxanmod_sysfs.c` to expose the new tunable set.
