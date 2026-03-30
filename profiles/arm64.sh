#!/usr/bin/env bash
# shellcheck disable=SC2034  # vars are sourced and used by build.sh
# profiles/arm64.sh — ARM64 (Raspberry Pi 5, Apple Silicon via Asahi, etc.)
# Hybrid mode. XanMod ARM64 configs are experimental; Zen patches apply
# cleanly on arm64 as of 6.x.

MODE=hybrid
BRANCH=MAIN
KARCH=arm64
ENABLE_ZEN_PATCHES=1
ENABLE_LQX_PATCHES=1
NO_DEBUG=1
LZ4_SWAP=1
