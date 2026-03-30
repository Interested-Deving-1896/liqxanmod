# Adding a new architecture

## Supported architectures

| Architecture | Kernel ARCH | Status |
|---|---|---|
| x86-64 | `x86` | Full support |
| ARM64 | `arm64` | Experimental |
| RISC-V 64 | `riscv` | Experimental |

## Steps to add a new architecture

### 1. Generate a base config

Use the `gen-arch-config` GitHub Actions workflow (`.github/workflows/gen-arch-config.yml`)
to cross-compile a `defconfig` for the target architecture. Trigger it manually
from the Actions tab with the target arch and kernel version.

Alternatively, generate it locally:

```bash
# ARM64 example
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
cp .config /path/to/liqxanmod/configs/base/aarch64.config
```

### 2. Add a base config fragment

Place the generated config at `configs/base/<arch>.config`. The filename must
match the value returned by `detect_karch()` in `scripts/lib/detect.sh`:

| `uname -m` | `detect_karch()` | Config file |
|---|---|---|
| `x86_64` | `x86` | `configs/base/x86-64-{v1,v2,v3,v4}.config` |
| `aarch64` | `arm64` | `configs/base/aarch64.config` |
| `riscv64` | `riscv` | `configs/base/riscv64.config` |

### 3. Wire it into build.sh

`build.sh` already handles `arm64` and `riscv` in the config fragment
selection block. For a new architecture, add a branch:

```bash
elif [[ "${KARCH}" == "myarch" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/myarch.config")
fi
```

### 4. Add a profile (optional)

Create `profiles/myarch.sh` following the pattern in `profiles/arm64.sh`.
Set `KARCH=myarch` and `CROSS_COMPILE=myarch-linux-gnu-` if cross-compiling.

### 5. Verify patch applicability

Not all XanMod or Zen patches are architecture-neutral. Test with
`--no-install` first:

```bash
./build.sh --no-install KARCH=myarch CROSS_COMPILE=myarch-linux-gnu-
```

Patches that fail on the new architecture should be guarded with an
`#ifdef CONFIG_X86` (or equivalent) in the patch itself, or excluded from
the series file with a comment explaining why.
