# Adding patches

## Patch series directories

| Directory | Applied when | Source |
|-----------|-------------|--------|
| `patches/core/` | Always | Manual |
| `patches/liquorix/zen/` | `ENABLE_ZEN_PATCHES=1` | Auto-fetched from damentz/liquorix-package |
| `patches/liquorix/lqx/` | `ENABLE_LQX_PATCHES=1` | Auto-fetched from damentz/liquorix-package |
| `patches/hybrid/` | `MODE=hybrid\|auto` | Manual — conflict resolution only |
| `patches/xanmod/sched/` | `ENABLE_CACHY=1` | From XanMod source tree |
| `patches/xanmod/fs/` | `ENABLE_FS_PATCHES=1` | From XanMod source tree |
| `patches/xanmod/net/` | `ENABLE_NET_PATCHES=1` | From XanMod source tree |
| `patches/xanmod/boot/` | `ENABLE_PARALLEL_BOOT=1` | From XanMod source tree |
| `patches/xanmod/hardware/asus-rog/` | `ENABLE_ROG=1` | From arglebargle-arch/xanmod-rog-PKGBUILD |
| `patches/xanmod/hardware/mediatek-bt/` | `ENABLE_MEDIATEK_BT=1` | From arglebargle-arch/xanmod-rog-PKGBUILD |

## Adding a patch to an existing series

1. Copy the `.patch` file into the appropriate directory.
2. Add its filename on a new line in that directory's `series` file.
3. Order matters — patches are applied top-to-bottom. Place the new patch
   after any patches it depends on.

Example — adding a network patch:

```bash
cp my-bbr3-tweak.patch patches/xanmod/net/
echo "my-bbr3-tweak.patch" >> patches/xanmod/net/series
```

## Creating a new patch from a kernel tree change

```bash
# Make your change in kernel/src, then:
cd kernel/src
git diff > ../../patches/xanmod/net/my-bbr3-tweak.patch
echo "my-bbr3-tweak.patch" >> ../../patches/xanmod/net/series
```

## Patch format requirements

- Standard unified diff (`diff -u` or `git format-patch`)
- `-p1` strip level (paths relative to kernel root)
- No trailing whitespace in context lines
- Include a `Subject:` header describing the change

## Rebasing patches to a new kernel version

When XanMod or Liquorix updates to a new kernel version, patches may fail
to apply cleanly. `apply-patches.sh` will attempt a 3-way merge
(`patch --merge`) before aborting. If the 3-way merge leaves conflict
markers, resolve them manually:

```bash
# Run build with --no-fetch to skip re-cloning
./build.sh --no-fetch --no-install

# If a patch fails, edit the conflicted file in kernel/src/,
# remove conflict markers, then re-run.
```

After resolving, regenerate the patch:

```bash
cd kernel/src
git diff HEAD > ../../patches/<series>/my-patch.patch
```

## Hybrid glue patches

Patches in `patches/hybrid/` are special — they exist solely to resolve
symbol conflicts between XanMod and Zen patches. Before adding a new glue
patch, document the conflict in `docs/hybrid-design.md` and in the comment
block at the top of `patches/hybrid/series`.
