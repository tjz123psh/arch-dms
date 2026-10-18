#!/usr/bin/env bash
# 04-desktop.sh — install the selected desktop environment(s).
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

section "Desktop environment (${DESKTOP_ENV})"

case "${DESKTOP_ENV}" in
  none)
    log "No desktop selected; skipping compositor packages"
    ;;
  niri)
    log "Installing Niri..."
    run pacman -S --needed --noconfirm niri xdg-desktop-portal-gnome xwayland-satellite
    ;;
esac

success "Desktop packages installed (${DESKTOP_ENV})"
