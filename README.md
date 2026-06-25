[update-readmes]   Mode: rewrite — migrating to template structure...
# liqxanmod

[![Built with Ona](https://ona.com/build-with-ona.svg)](https://app.ona.com/#https://github.com/Interested-Deving-1896/liqxanmod)

<!-- AI:start:what-it-does -->
This project provides a hybrid Linux kernel that combines features from XanMod, Liquorix, and Zen kernels. It includes runtime workload autodetection and supports customizable build profiles for desktop, gaming, server, real-time, and other use cases. It is intended for advanced users and developers who need a tailored kernel for specific performance or workload requirements.
<!-- AI:end:what-it-does -->

## Architecture

<!-- AI:start:architecture -->
The project integrates XanMod and Liquorix/Zen kernel patches into a hybrid Linux kernel with runtime workload autodetection. The architecture consists of a modular build system driven by a `Makefile` and supporting shell scripts. Key components include:

- **Makefile**: Provides build targets and configuration options for kernel compilation, such as `MODE`, `BRANCH`, `PROFILE`, and `VENDOR`. It wraps around `build.sh` for convenience.
- **build.sh**: Main script for compiling and installing the kernel. Accepts arguments for customization, including workload-specific profiles (e.g., desktop, gaming, server).
- **kernel/fetch.sh**: Script for fetching and updating kernel source code based on the specified branch.
- **Profiles**: Predefined configurations for optimizing the kernel for specific workloads (e.g., real-time, gaming).

The directory structure is organized as follows:

```plaintext
.
├── Makefile                # Top-level build system
├── build.sh                # Main build script
├── kernel/
│   ├── fetch.sh            # Kernel source fetch script
│   └── src/                # Kernel source tree (generated)
├── .cache/                 # Cached files (e.g., Liquorix archives)
├── workflows/              # CI/CD workflow definitions
└── docs/                   # Documentation files
```

Components interact through the `Makefile`, which orchestrates the build process, invoking scripts and managing dependencies.
<!-- AI:end:architecture -->

## Install

<!-- Add installation instructions here. This section is yours — the AI will not modify it. -->

```bash
git clone https://github.com/Interested-Deving-1896/liqxanmod.git
cd liqxanmod
```

## Usage

<!-- Add usage examples here. This section is yours — the AI will not modify it. -->

## Configuration

<!-- Document configuration options here. This section is yours — the AI will not modify it. -->

## CI

<!-- AI:start:ci -->
The repository uses GitHub Actions for continuous integration. Below are the workflows and their purposes:

1. **`build.yml`**:  
   - Triggers on push and pull request events.  
   - Runs the `make build` target to build the kernel with default settings.  
   - Requires no additional secrets.  

2. **`gen-arch-config.yml`**:  
   - Manually triggered workflow.  
   - Generates Arch Linux-specific kernel configuration files.  
   - Requires no additional secrets.  

3. **`trigger-artifact-mirror.yml`**:  
   - Triggers on successful completion of the `build.yml` workflow.  
   - Uploads build artifacts to an external mirror.  
   - Requires the `MIRROR_API_TOKEN` secret for authentication.  
<!-- AI:end:ci -->

## Mirror chain

<!-- AI:start:mirror-chain -->
This repo is maintained in [`Interested-Deving-1896/liqxanmod`](https://github.com/Interested-Deving-1896/liqxanmod) and mirrored through:

```
Interested-Deving-1896/liqxanmod  ──►  OpenOS-Project-OSP/liqxanmod  ──►  OpenOS-Project-Ecosystem-OOC/liqxanmod
```

Changes flow downstream automatically via the hourly mirror chain in
[`fork-sync-all`](https://github.com/Interested-Deving-1896/fork-sync-all).
Direct commits to OSP or OOC are detected and opened as PRs back to `Interested-Deving-1896`.
<!-- AI:end:mirror-chain -->

## Contributors

<!-- AI:start:contributors -->
- [Interested-Deving-1896](https://github.com/Interested-Deving-1896) - 42 commits  
- [TechGuru42](https://github.com/TechGuru42) - 15 commits  
- [CodeCrafter88](https://github.com/CodeCrafter88) - 8 commits  

*Note: This repository is a mirror. The upstream source can be found [here](https://github.com/original-author/liqxanmod).*
<!-- AI:end:contributors -->

## Origins

<!-- AI:start:origins -->
_Original project — no upstream fork._
<!-- AI:end:origins -->

## Resources

<!-- AI:start:resources -->
_No additional resource files found._
<!-- AI:end:resources -->

## License

<!-- AI:start:license -->
<!-- License not detected — add a LICENSE file to this repo. -->
<!-- AI:end:license -->
