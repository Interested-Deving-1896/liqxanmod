# LiqXanMod

A hybrid Linux kernel that merges the [XanMod](https://xanmod.org) performance
patch set with the [Liquorix/Zen](https://liquorix.net) low-latency patch set
into a single kernel image.

Both patch sets are compiled in simultaneously. A lightweight in-kernel
workload detector (`drivers/liqxanmod/`) samples CPU runqueue depth, wakeup
frequency, and IRQ rate every 100 ms and switches the active scheduler profile
at runtime — no reboot required.

---

## Quick start

```bash
git clone https://github.com/YOUR_ORG/liqxanmod
cd liqxanmod

# Auto-detect distro, arch, microarch, and workload profile
./build.sh

# Named profiles
./build.sh --profile desktop
./build.sh --profile gaming
./build.sh --profile server   # XanMod-only, no autodetect overhead
./build.sh --profile rt       # Liquorix-only, PREEMPT_RT branch

# Explicit mode
./build.sh --mode hybrid   # both patch sets + runtime autodetect (default)
./build.sh --mode xanmod   # XanMod patches only
./build.sh --mode liquorix # Zen/Liquorix patches only
./build.sh --mode auto     # alias for hybrid

# Build without installing
./build.sh --no-install
```

Or via Make:

```bash
make                          # hybrid, MAIN branch
make profile-gaming
make MODE=xanmod BRANCH=LTS
make build-only JOBS=16
```

---

## Modes

| Mode | Patch sets compiled in | Runtime autodetect |
|------|------------------------|--------------------|
| `hybrid` | XanMod + Zen/Liquorix | ✅ yes |
| `auto` | XanMod + Zen/Liquorix | ✅ yes (alias) |
| `xanmod` | XanMod only | ❌ no |
| `liquorix` | Zen/Liquorix only | ❌ no |

---

## Runtime autodetect

When `MODE=hybrid`, the kernel runs a kthread (`lqxm_detect`) that classifies
the workload every 100 ms and switches the active scheduler profile after 5
consecutive stable samples (500 ms hysteresis).

### Profiles

| Profile | Scheduler tunables | When selected |
|---------|-------------------|---------------|
| `throughput` | Wide CFS slices (XanMod values) | High runqueue depth, batch work |
| `latency` | Narrow CFS slices (Zen values) | High wakeup/IRQ rate, interactive |
| `balanced` | Midpoint | Neither extreme |

### Sysfs interface

```
/sys/kernel/liqxanmod/
  active_profile        rw  "throughput" | "latency" | "balanced"
  autodetect            rw  "1" = auto-switch, "0" = pin current profile
  detector/
    rq_depth_throughput_x100   rw  RQ depth threshold × 100 (default 300 = 3.0)
    rq_depth_latency_x100      rw  RQ depth threshold × 100 (default 120 = 1.2)
    wakeup_rate_latency        rw  wakeups/s threshold (default 50000)
    irq_rate_latency           rw  IRQs/s threshold (default 20000)
```

Pin to latency profile permanently:

```bash
echo 0 > /sys/kernel/liqxanmod/autodetect
echo latency > /sys/kernel/liqxanmod/active_profile
```

Tune the throughput threshold for a compile-heavy workstation:

```bash
echo 500 > /sys/kernel/liqxanmod/detector/rq_depth_throughput_x100  # 5.0
```

---

## Profiles

| Profile | Mode | Branch | Key features |
|---------|------|--------|--------------|
| `desktop` | hybrid | MAIN | Net patches, LZ4 swap |
| `gaming` | hybrid | MAIN | Net + FS patches, LZ4 swap |
| `server` | xanmod | LTS | Net + FS + CachyOS, no autodetect |
| `rt` | liquorix | RT | PREEMPT_RT, latency pinned |
| `rog` | hybrid | MAIN | ROG + MediaTek BT patches |
| `arm64` | hybrid | MAIN | ARM64 cross-build |

---

## Feature flags

All flags are environment variables. Set them on the command line or in a
profile file under `profiles/`.

| Variable | Default | Description |
|----------|---------|-------------|
| `MODE` | `hybrid` | Patch blend mode |
| `BRANCH` | `MAIN` | XanMod source branch |
| `LQX_VER` | auto | Liquorix version (e.g. `6.12.1-1`) |
| `MLEVEL` | auto | x86-64 microarch level (v1–v4) |
| `VENDOR` | — | `amd` or `intel` config fragment |
| `ENABLE_ZEN_PATCHES` | `1` | Zen scheduler + latency patches |
| `ENABLE_LQX_PATCHES` | `1` | Liquorix tuning patches |
| `ENABLE_CACHY` | `0` | CachyOS scheduler (XanMod side) |
| `ENABLE_FS_PATCHES` | `0` | XanMod filesystem patches |
| `ENABLE_NET_PATCHES` | `0` | XanMod network patches |
| `ENABLE_ROG` | `0` | ASUS ROG patches + config |
| `ENABLE_MEDIATEK_BT` | `0` | MediaTek MT7921 BT patches |
| `ENABLE_PARALLEL_BOOT` | `0` | Parallel boot patch |
| `NO_DEBUG` | `0` | Disable debug/tracing overhead |
| `LZ4_SWAP` | `0` | LZ4 compressed swap |
| `EXTRA_CONFIG` | — | Additional .config fragment (highest priority) |
| `JOBS` | `nproc` | Parallel build jobs |
| `DO_FETCH` | `1` | Fetch/update kernel source before build |
| `DO_INSTALL` | `1` | Install after build |

---

## Distro support

### Supported

| Backend | Distros |
|---------|---------|
| `debian` | Debian, Ubuntu + all flavours, Mint, Zorin, Pop!\_OS, elementary, KDE neon, Kali, Parrot, Devuan, MX Linux, antiX, Proxmox, deepin¹, TUXEDO, PikaOS, Rhino, and 40+ more |
| `arch` | Arch, EndeavourOS, Manjaro, CachyOS, Garuda, Artix, Archcraft, RebornOS |
| `fedora` | Fedora, Nobara, Bazzite, Ultramarine |
| `rhel` | RHEL, AlmaLinux, Rocky, Oracle, CentOS Stream |
| `opensuse` | openSUSE Tumbleweed, Leap, Regata |
| `gentoo` | Gentoo, Calculate, Funtoo |
| `generic` | Fallback: `make install` + auto-detected initramfs/bootloader |

> ¹ deepin: the installer automatically enables/disables the immutable root
> filesystem around the install step.

### Not supported

NixOS (declarative kernel model), Alpine (musl libc), FreeBSD/OpenBSD (not Linux).

---

## Architecture support

| Architecture | Status |
|---|---|
| x86-64 v1–v4 | ✅ Full support, auto-detected |
| ARM64 | ⚠️ Experimental — use `profiles/arm64.sh` |
| RISC-V 64 | ⚠️ Experimental — trigger `gen-arch-config` workflow first |

---

## Repository layout

```
liqxanmod/
├── build.sh                    Main entry point
├── Makefile                    Convenience targets
├── VERSION
├── kernel/
│   ├── fetch.sh                Clone/update gitlab.com/xanmod/linux
│   ├── liqxanmod_autodetect.c  Runtime workload detector (injected at build time)
│   └── src/                    Kernel source tree (git-ignored)
├── patches/
│   ├── core/                   Applied unconditionally
│   ├── hybrid/                 Glue patches resolving XanMod↔Zen conflicts
│   │   ├── series
│   │   ├── 0001-liqxanmod-kconfig-symbol.patch
│   │   ├── 0002-liqxanmod-sysfs-bridge.patch
│   │   └── 0003-liqxanmod-dedup-sched-nr-latency.patch
│   ├── xanmod/
│   │   ├── sched/              CachyOS scheduler
│   │   ├── fs/                 Filesystem patches
│   │   ├── net/                Network patches
│   │   ├── boot/               Parallel boot
│   │   └── hardware/{asus-rog,mediatek-bt}/
│   └── liquorix/
│       ├── zen/                Zen scheduler + latency (fetched at build time)
│       └── lqx/                Liquorix tuning (fetched at build time)
├── configs/
│   ├── base/                   Per-arch base configs (x86-64-v1–v4, aarch64, riscv64)
│   ├── arch/                   CPU vendor overrides (amd, intel)
│   ├── features/               Mode configs (xanmod, liquorix, hybrid, rt, no-debug, lz4-swap)
│   └── hardware/               Hardware-specific fragments (asus-rog)
├── profiles/                   Named build profiles
│   └── desktop.sh  gaming.sh  server.sh  rt.sh  rog.sh  arm64.sh
├── scripts/
│   ├── lib/
│   │   ├── log.sh              Logging helpers
│   │   └── detect.sh           Arch, distro, microarch, workload detection
│   ├── apply-patches.sh        Ordered patch application with conflict handling
│   ├── fetch-lqx-patches.sh    Download and stage Liquorix patch archive
│   ├── inject-autodetect.sh    Copy autodetect module into kernel tree
│   └── resolve-lqx-version.sh  Query latest Liquorix release from GitHub API
├── packaging/
│   ├── debian/   arch/   fedora/   opensuse/   gentoo/   generic/
│   └── */install.sh
├── docs/
│   ├── hybrid-design.md        Architecture and conflict resolution details
│   ├── autodetect.md           Runtime detector internals and tuning guide
│   ├── adding-patches.md       How to add new patches to any series
│   └── adding-arch.md          How to author a config for a new architecture
└── .github/workflows/
    ├── build.yml               CI matrix: modes × distros × branches
    └── gen-arch-config.yml     Manual workflow to generate arm64/riscv64 configs
```

---

## Patch application order

```
1. patches/core/                 unconditional base fixes
2. patches/liquorix/zen/         Zen scheduler + latency  (if ENABLE_ZEN_PATCHES)
3. patches/liquorix/lqx/         Liquorix tuning          (if ENABLE_LQX_PATCHES)
4. patches/hybrid/               XanMod↔Zen glue          (if MODE=hybrid|auto)
5. patches/xanmod/sched/         CachyOS scheduler        (if ENABLE_CACHY)
6. patches/xanmod/fs/            filesystem               (if ENABLE_FS_PATCHES)
7. patches/xanmod/net/           network                  (if ENABLE_NET_PATCHES)
8. patches/xanmod/boot/          parallel boot            (if ENABLE_PARALLEL_BOOT)
9. patches/xanmod/hardware/asus-rog/                      (if ENABLE_ROG)
10. patches/xanmod/hardware/mediatek-bt/                  (if ENABLE_MEDIATEK_BT)
```

Zen patches land before XanMod scheduler patches so the hybrid glue can
reference Zen-introduced symbols when deduplicating conflicts.

---

## License

GPL-2.0 — same as the Linux kernel.
