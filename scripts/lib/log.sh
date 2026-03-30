#!/bin/bash
# Logging helpers. Source this file; do not execute directly.

# log LEVEL message
# Levels: INFO WARN ERROR
log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts="$(date '+%H:%M:%S')"
  case "${level}" in
    INFO)  printf '[%s] \033[32mINFO\033[0m  %s\n' "${ts}" "${msg}" ;;
    WARN)  printf '[%s] \033[33mWARN\033[0m  %s\n' "${ts}" "${msg}" >&2 ;;
    ERROR) printf '[%s] \033[31mERROR\033[0m %s\n' "${ts}" "${msg}" >&2 ;;
    *)     printf '[%s] %s  %s\n' "${ts}" "${level}" "${msg}" ;;
  esac
}
