#!/usr/bin/env bash
# lib/common.sh — helpers shared by install.sh and the step scripts.
# Sourced, never executed directly.

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_DIR
# shellcheck disable=SC2034  # consumed by the step scripts
readonly MANIFESTS_DIR="${PROJECT_DIR}/manifests"
# shellcheck disable=SC2034
readonly CONFIG_DIR="${PROJECT_DIR}/config"

# --- output -----------------------------------------------------------------
if [[ -t 1 ]]; then
  H_RED=$'\e[31m'; H_GREEN=$'\e[32m'; H_YELLOW=$'\e[33m'
  H_CYAN=$'\e[36m'; DIM=$'\e[2m'; NC=$'\e[0m'
else
  H_RED=""; H_GREEN=""; H_YELLOW=""; H_CYAN=""; DIM=""; NC=""
fi

log()     { echo -e "  ${DIM}->${NC} $*"; }
section() { echo; echo -e "${H_CYAN}===[ $* ]${NC}"; }
success() { echo -e "  ${H_GREEN}✔${NC} $*"; }
warn()    { echo -e "  ${H_YELLOW}!${NC} $*"; }
error()   { echo -e "  ${H_RED}✘${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# --- privilege --------------------------------------------------------------
# The installer runs either as the desktop user (./install.sh) or as root
# (strap.sh). run() is the single sudo entry point for privileged commands.
run() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# --- target user ------------------------------------------------------------
# root/strap path: the desktop user is SUDO_USER (or the first uid >= 1000).
# Everything user-scoped (config, user units, AUR builds) targets that user,
# never /root.
if [[ "$(id -u)" -eq 0 ]]; then
  TARGET_USER="${SUDO_USER:-}"
  if [[ -z "${TARGET_USER}" ]]; then
    TARGET_USER="$(awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ { print $1; exit }' /etc/passwd)"
  fi
  TARGET_HOME="$(getent passwd "${TARGET_USER:-root}" | cut -d: -f6)"
  TARGET_HOME="${TARGET_HOME:-/root}"
  TARGET_USER="${TARGET_USER:-root}"
else
  TARGET_USER="$(id -un)"
  TARGET_HOME="${HOME}"
fi
readonly TARGET_USER TARGET_HOME

# Run a command as the target user with HOME set explicitly, so it works on
# the root/strap path too.
as_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    runuser -u "${TARGET_USER}" -- env HOME="${TARGET_HOME}" "$@"
  else
    "$@"
  fi
}

# chown a path to the target user (no-op when already running as that user).
chown_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "$@" 2>/dev/null || true
  fi
}

# --- module selection -------------------------------------------------------
# Shared by the package and config steps: one rule set decides which manifest
# rows a given desktop installs. Hardware modules are the driver step's job
# for packages; their configs deploy normally.
module_selected() { # module_selected <module> [package|config]
  local module="$1" ctx="${2:-package}"
  case "${module}" in
    graphics-amd|graphics-nvidia|hardware-tools|asus-hardware)
      [[ "${ctx}" == "config" ]] ;;
    wm-niri) [[ "${DESKTOP_ENV:-niri}" != "none" ]] ;;
    dms-shell|dms-greetd) [[ "${DESKTOP_ENV:-niri}" != "none" ]] ;;
    *) return 0 ;;
  esac
}
