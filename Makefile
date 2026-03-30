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
        lint shellcheck

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
