#!/bin/bash
# Distro, architecture, and microarch detection helpers.
# Source this file; do not execute directly.

# detect_karch prints the kernel ARCH string used by the build system.
detect_karch() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64)          echo "x86" ;;
    aarch64|arm64)   echo "arm64" ;;
    riscv64)         echo "riscv" ;;
    *)
      echo "ERROR: Unsupported host architecture: ${machine}" >&2
      echo "       Set KARCH and CROSS_COMPILE manually for cross-compilation." >&2
      exit 1
      ;;
  esac
}

# detect_mlevel prints the x86-64 microarch level (v1–v4) by reading
# /proc/cpuinfo flags. Returns empty string for non-x86 arches.
detect_mlevel() {
  local karch="${1:-}"
  [[ "${karch}" != "x86" ]] && echo "" && return

  local flags
  flags=$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null || echo "")

  if echo "${flags}" | grep -q 'avx512f'; then
    echo "v4"
  elif echo "${flags}" | grep -q 'avx2'; then
    echo "v3"
  elif echo "${flags}" | grep -q 'sse4_2'; then
    echo "v2"
  else
    echo "v1"
  fi
}

# detect_distro prints a normalized distro token used to dispatch packaging.
#
# Tokens: debian | arch | gentoo | fedora | rhel | opensuse | alpine | void |
#         slackware | generic
#
# Detection order:
#   1. /etc/os-release ID exact match
#   2. /etc/os-release ID_LIKE fallback
#   3. Package manager presence
detect_distro() {
  local os_id="" os_id_like=""

  if [[ -f /etc/os-release ]]; then
    os_id=$(. /etc/os-release 2>/dev/null && echo "${ID:-}")
    os_id_like=$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}")
  fi

  # Explicit ID match
  case "${os_id}" in
    alpine)    echo "alpine";    return ;;
    void)      echo "void";      return ;;
    slackware) echo "slackware"; return ;;
    gentoo|calculate|funtoo)
               echo "gentoo";    return ;;
    arch|manjaro|endeavouros|cachyos|garuda|\
    artix|archcraft|rebornos|blendos|parabola)
               echo "arch";      return ;;
    opensuse*|suse*|sles*)
               echo "opensuse";  return ;;
    fedora|nobara|bazzite|ultramarine)
               echo "fedora";    return ;;
    centos|rhel|almalinux|rocky|ol|amzn|scientific|eurolinux)
               echo "rhel";      return ;;
    ubuntu|kubuntu|xubuntu|lubuntu)
               echo "debian";    return ;;
    debian|linuxmint|pop|elementary|kali|parrot|devuan|sparky|\
    bunsen|proxmox|zorin|deepin|mx|antix|bodhi|peppermint|feren|\
    rhino|pika|biglinux|dragonos|anduinos|linuxfx|voyager|lite|\
    q4os|emmabuntus|kodachi|watt|makululinux|tails|endless|\
    tuxedo|funos|vanilla|qubes)
               echo "debian";    return ;;
  esac

  # ID_LIKE fallback
  case "${os_id_like}" in
    *alpine*)            echo "alpine";    return ;;
    *archlinux*|*arch*)  echo "arch";      return ;;
    *gentoo*)            echo "gentoo";    return ;;
    *fedora*|*rhel*|*centos*)
      # Distinguish Fedora vs RHEL derivatives by ID
      case "${os_id}" in
        fedora|nobara|bazzite|ultramarine) echo "fedora" ;;
        *) echo "rhel" ;;
      esac
      return
      ;;
    *opensuse*|*suse*)   echo "opensuse";  return ;;
    *debian*|*ubuntu*)   echo "debian";    return ;;
  esac

  # Package manager presence fallback
  if   command -v apk          &>/dev/null; then echo "alpine"
  elif command -v xbps-install &>/dev/null; then echo "void"
  elif command -v installpkg   &>/dev/null; then echo "slackware"
  elif command -v pacman       &>/dev/null; then echo "arch"
  elif command -v emerge       &>/dev/null; then echo "gentoo"
  elif command -v zypper       &>/dev/null; then echo "opensuse"
  elif command -v dnf          &>/dev/null; then echo "fedora"
  elif command -v yum          &>/dev/null; then echo "rhel"
  elif command -v apt          &>/dev/null; then echo "debian"
  else echo "generic"
  fi
}

# detect_cpu_vendor prints "amd" or "intel" by reading /proc/cpuinfo.
# Returns empty string if undetermined.
detect_cpu_vendor() {
  local vendor
  vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')
  case "${vendor}" in
    AuthenticAMD) echo "amd" ;;
    GenuineIntel) echo "intel" ;;
    *)            echo "" ;;
  esac
}

# detect_workload_profile prints a hint about the current system's primary use.
# Used by the build system to suggest a default profile when none is specified.
#
# Heuristics (in priority order):
#   rt        — PREEMPT_RT kernel already running, or jackd/pipewire-rt present
#   gaming    — Steam, Lutris, or Proton detected
#   desktop   — X11/Wayland session running
#   server    — No display server, uptime > 1h, multiple services
#   default   — fallback
detect_workload_profile() {
  # Real-time audio/video workload
  if uname -r | grep -q '\-rt' 2>/dev/null; then
    echo "rt"; return
  fi
  if command -v jackd &>/dev/null || command -v pw-jack &>/dev/null; then
    echo "rt"; return
  fi

  # Gaming
  if command -v steam &>/dev/null || command -v lutris &>/dev/null; then
    echo "gaming"; return
  fi
  if [[ -d "${HOME}/.steam" || -d "${HOME}/.local/share/Steam" ]]; then
    echo "gaming"; return
  fi

  # Desktop (display server present)
  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "desktop"; return
  fi
  if pgrep -x Xorg &>/dev/null || pgrep -x Xwayland &>/dev/null \
     || pgrep -x sway &>/dev/null || pgrep -x gnome-shell &>/dev/null; then
    echo "desktop"; return
  fi

  # Server (headless, long uptime)
  local uptime_sec
  uptime_sec=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
  if [[ "${uptime_sec}" -gt 3600 ]] && [[ -z "${DISPLAY:-}" ]]; then
    echo "server"; return
  fi

  echo "default"
}
