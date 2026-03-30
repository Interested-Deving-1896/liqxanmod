#!/usr/bin/env bash
# shellcheck disable=SC2034  # vars are sourced and used by build.sh
# profiles/rt.sh — hard real-time (audio production, industrial)
# Liquorix-only mode on the RT branch. Autodetect disabled; latency
# profile is pinned at boot.

MODE=liquorix
BRANCH=RT
ENABLE_ZEN_PATCHES=1
ENABLE_LQX_PATCHES=1
ENABLE_CACHY=0
NO_DEBUG=1
LZ4_SWAP=0
# Pin to latency profile; disable autodetect switching
EXTRA_CONFIG="${REPO_ROOT}/configs/features/rt.config"
