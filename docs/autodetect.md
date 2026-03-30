# Runtime autodetect internals

## Overview

The autodetect module (`drivers/liqxanmod/autodetect.c`) runs as a kernel
thread and classifies the running workload every 100 ms. After 5 consecutive
samples with the same classification (500 ms hysteresis), it calls
`lqxm_apply_profile()` to update the active CFS tunable set.

Only compiled in when `CONFIG_LIQXANMOD_HYBRID=y` (i.e. `MODE=hybrid` or
`MODE=auto`).

## Metrics

| Metric | Source | Description |
|--------|--------|-------------|
| `avg_rq_depth` | `cpu_rq(cpu)->nr_running` averaged across online CPUs | Mean number of runnable tasks per CPU |
| `wakeup_rate` | `schedstat` delta / elapsed time | Wakeups per second across all CPUs |
| `irq_rate` | `kstat_irqs_cpu()` delta / elapsed time | IRQs per second across all CPUs and vectors |

`wakeup_rate` and `irq_rate` require `CONFIG_SCHEDSTATS=y`, which is set by
`configs/features/hybrid.config`.

## Classification logic

```
if wakeup_rate >= wakeup_rate_latency  →  LATENCY   (interactive/audio)
if irq_rate    >= irq_rate_latency     →  LATENCY   (USB/audio IRQ storm)
if avg_rq_depth <= rq_depth_latency    →  LATENCY   (idle/light load)
if avg_rq_depth >= rq_depth_throughput →  THROUGHPUT (compile/batch)
else                                   →  BALANCED
```

Latency signals take priority over runqueue depth. A system compiling code
while playing audio will be classified as LATENCY because the IRQ/wakeup rate
from the audio subsystem exceeds the threshold.

## Tunable defaults

| Sysfs path | Default | Meaning |
|---|---|---|
| `detector/rq_depth_throughput_x100` | 300 | avg RQ depth ≥ 3.0 → throughput |
| `detector/rq_depth_latency_x100` | 120 | avg RQ depth ≤ 1.2 → latency |
| `detector/wakeup_rate_latency` | 50000 | wakeups/s ≥ 50k → latency |
| `detector/irq_rate_latency` | 20000 | IRQs/s ≥ 20k → latency |

## Tuning examples

### Audio production workstation

Lower the IRQ threshold so the kernel switches to latency profile as soon as
the audio interface starts generating interrupts:

```bash
echo 5000 > /sys/kernel/liqxanmod/detector/irq_rate_latency
```

### Compile server that also runs a desktop

Raise the throughput threshold so the kernel stays in throughput profile
during parallel builds even when a few interactive tasks are running:

```bash
echo 600 > /sys/kernel/liqxanmod/detector/rq_depth_throughput_x100  # 6.0
```

### Pin a profile permanently

```bash
echo 0       > /sys/kernel/liqxanmod/autodetect
echo latency > /sys/kernel/liqxanmod/active_profile
```

### Re-enable autodetect after pinning

```bash
echo 1 > /sys/kernel/liqxanmod/autodetect
```

## Profile tunable sets

These are the CFS values applied when each profile is activated:

| Tunable | throughput | balanced | latency |
|---------|-----------|---------|---------|
| `sysctl_sched_latency` | 10 ms | 6 ms | 4 ms |
| `sysctl_sched_min_granularity` | 1 ms | 0.75 ms | 0.3 ms |
| `sysctl_sched_wakeup_granularity` | 1.5 ms | 1 ms | 0.5 ms |
| `sched_nr_latency` | 10 | 8 | 4 |

The `throughput` values match XanMod defaults. The `latency` values match
Zen/Liquorix defaults. `balanced` is the midpoint.

## Hysteresis

The detector requires 5 consecutive samples (500 ms) with the same
classification before switching profiles. This prevents thrashing when a
workload oscillates between thresholds (e.g. a game that alternates between
CPU-bound rendering and idle waiting).

The hysteresis count resets whenever the classification changes, so a single
outlier sample does not delay a genuine transition.
