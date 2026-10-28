# LiqXanMod — top-level Makefile
#
# Convenience targets that wrap build.sh.
# All variables can be overridden on the command line, e.g.:
#   make build MODE=xanmod BRANCH=LTS VENDOR=amd JOBS=8

SHELL   := /bin/bash
JOBS    ?= $(shell nproc)
MODE    ?= hybrid
BRANCH  ?= MAIN
PROFILE ?=
VENDOR  ?=
MLEVEL  ?=

BUILD_ARGS := --mode $(MODE) --branch $(BRANCH) --jobs $(JOBS)
ifneq ($(PROFILE),)
  BUILD_ARGS += --profile $(PROFILE)
endif
ifneq ($(VENDOR),)
  BUILD_ARGS += --vendor $(VENDOR)
endif
ifneq ($(MLEVEL),)
  BUILD_ARGS += --mlevel $(MLEVEL)
endif

.PHONY: all build build-only fetch clean distclean help \
        profile-desktop profile-gaming profile-server profile-rt profile-rog \
        lint shellcheck bdfs-module

## Default: full build + install
all: build

## Full build and install
build:
	bash build.sh $(BUILD_ARGS)

## Build only, skip install
build-only:
	bash build.sh $(BUILD_ARGS) --no-install

## Fetch kernel source only
fetch:
	bash kernel/fetch.sh $(BRANCH)

## Named profile shortcuts
profile-desktop:
	bash build.sh --profile desktop --jobs $(JOBS)

profile-gaming:
	bash build.sh --profile gaming --jobs $(JOBS)

profile-server:
	bash build.sh --profile server --jobs $(JOBS)

profile-rt:
	bash build.sh --profile rt --jobs $(JOBS)

profile-rog:
	bash build.sh --profile rog --jobs $(JOBS)

## Remove cached Liquorix archives
clean:
	rm -rf .cache/lqx

## Remove kernel source tree and all caches
distclean: clean
	rm -rf kernel/src

## Lint all shell scripts with shellcheck
shellcheck:
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	find . -name '*.sh' ! -path './.cache/*' ! -path './kernel/src/*' \
	  -exec shellcheck -x {} +

lint: shellcheck

# ── Btrfs-DwarFS Framework (BDFS) external module ─────────────────────────────
# Requires a configured kernel/src tree and BDFS checkout with the shared helper.
BDFS_DIR ?= $(shell \
    if [ -f "$(CURDIR)/../btrfs-dwarfs-framework/integrations/kernels/build-module.sh" ]; then \
        echo "$(CURDIR)/../btrfs-dwarfs-framework"; \
    elif [ -f "$(CURDIR)/../../btrfs-dwarfs-framework/integrations/kernels/build-module.sh" ]; then \
        echo "$(CURDIR)/../../btrfs-dwarfs-framework"; \
    else echo ""; fi)
KERNEL_BUILD_DIR ?= $(CURDIR)/kernel/src
BDFS_ARTIFACT_DIR ?= $(CURDIR)/artifacts/bdfs

.PHONY: bdfs-module
bdfs-module: ## Build and stage BDFS .ko against configured kernel/src (no install/load)
\t@[ -n "$(BDFS_DIR)" ] || { echo "Set BDFS_DIR=/path/to/btrfs-dwarfs-framework"; exit 1; }
\t@[ -f "$(BDFS_DIR)/integrations/kernels/build-module.sh" ] || { echo "BDFS external-module helper not found; use the BDFS integration branch or a revision with the helper merged."; exit 1; }
\t@[ -f "$(KERNEL_BUILD_DIR)/Makefile" ] && [ -f "$(KERNEL_BUILD_DIR)/.config" ] || { echo "Configured kernel tree not found at $(KERNEL_BUILD_DIR). Run make build-only/configuration first, or set KERNEL_BUILD_DIR explicitly."; exit 1; }
\tbash "$(BDFS_DIR)/integrations/kernels/build-module.sh" "$(KERNEL_BUILD_DIR)" "$(BDFS_ARTIFACT_DIR)"

help:
	@echo ""
	@echo "LiqXanMod build targets:"
	@echo ""
	@echo "  make                      Full build + install (MODE=hybrid BRANCH=MAIN)"
	@echo "  make build-only           Build without installing"
	@echo "  make fetch                Fetch/update kernel source only"
	@echo ""
	@echo "  make profile-desktop      Build with desktop profile"
	@echo "  make profile-gaming       Build with gaming profile"
	@echo "  make profile-server       Build with server profile (xanmod-only)"
	@echo "  make profile-rt           Build with RT profile (liquorix-only)"
	@echo "  make profile-rog          Build with ASUS ROG profile"
	@echo ""
	@echo "  make clean                Remove cached Liquorix archives"
	@echo "  make distclean            Remove kernel source tree + caches"
	@echo "  make shellcheck           Lint all shell scripts"
	@echo ""
	@echo "Variables (override on command line):"
	@echo "  MODE    hybrid|xanmod|liquorix|auto  (default: hybrid)"
	@echo "  BRANCH  MAIN|EDGE|LTS|RT             (default: MAIN)"
	@echo "  VENDOR  amd|intel                    (default: auto)"
	@echo "  MLEVEL  v1|v2|v3|v4                  (default: auto)"
	@echo "  JOBS    N                             (default: nproc)"
	@echo ""
