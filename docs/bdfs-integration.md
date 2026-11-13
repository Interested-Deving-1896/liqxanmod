# Btrfs-DwarFS Framework (BDFS) integration for LiqXanMod

BDFS currently ships an out-of-tree kernel module named `btrfs_dwarfs.ko`.
Its Kconfig symbol is `CONFIG_BTRFS_DWARFS`, and the registered filesystem
type is `bdfs_blend`. This is not an in-tree filesystem and does not establish
that BDFS can serve as a standalone root filesystem.

## Build the module

1. Fetch and configure the kernel source tree using the existing LiqXanMod
   workflow (the source tree is normally `kernel/src`).
2. Check out the BDFS revision containing
   `integrations/kernels/build-module.sh` (introduced by BDFS PR #18).
3. Run:

```sh
make bdfs-module BDFS_DIR=/path/to/btrfs-dwarfs-framework
```

Override `KERNEL_BUILD_DIR` if the configured source/build tree is not
`kernel/src`; override `BDFS_ARTIFACT_DIR` to change the output location.
The default output is `artifacts/bdfs/btrfs_dwarfs.ko`.

This target only builds and stages the module. It does not install or load it,
modify kernel defaults, package it into a release, or change rootfs boot
parameters. It requires a configured kernel tree with generated headers; the
kernel build workflow's normal build path should complete first.

## Next validation gates

- Compile against the supported kernel branches and architectures.
- Package the module with version dependency and signing policy.
- Test load/unload and `bdfs_blend` mount/unmount on disposable VMs.
- Validate initramfs and recovery separately before considering any rootfs
  or default-boot changes.
