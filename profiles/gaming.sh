#!/usr/bin/env bash
# profiles/gaming.sh — gaming / low-latency desktop
# Hybrid mode biased toward latency. Autodetect switches to throughput
# during shader compilation and back to latency during gameplay.

MODE=hybrid
BRANCH=MAIN
ENABLE_ZEN_PATCHES=1
ENABLE_LQX_PATCHES=1
ENABLE_NET_PATCHES=1
ENABLE_FS_PATCHES=1
NO_DEBUG=1
LZ4_SWAP=1
