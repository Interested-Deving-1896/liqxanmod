#!/usr/bin/env bash
# shellcheck disable=SC2034  # vars are sourced and used by build.sh
# profiles/server.sh — headless server / throughput workload
# XanMod-only mode. Zen patches excluded; no autodetect overhead.

MODE=xanmod
BRANCH=LTS
ENABLE_ZEN_PATCHES=0
ENABLE_LQX_PATCHES=0
ENABLE_NET_PATCHES=1
ENABLE_FS_PATCHES=1
ENABLE_CACHY=1
NO_DEBUG=1
LZ4_SWAP=0
