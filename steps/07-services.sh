#!/usr/bin/env bash
# 07-services.sh — enable the user and system services the desktop needs.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

DESKTOP_ENV="${DESKTOP_ENV:-niri}"
GREETER_USER=greeter
NWG_HELLO_DIR=/etc/nwg-hello

# systemctl --user for the target user. On the root/strap path that user may
# never have logged in, so create /run/user/<uid>, turn on linger and start the
# user manager first; XDG_CONFIG_HOME is pinned so enable writes the same
# ~/.config/systemd/user the units are deployed to.
userctl() {
  if [[ "$(id -u)" -ne 0 ]]; then
    # A plain SSH shell may lack XDG_RUNTIME_DIR; derive it from the live
    # session so systemctl --user can find the user bus.
    local ruid
    ruid="$(id -u)"
    if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/${ruid}" ]]; then
      export XDG_RUNTIME_DIR="/run/user/${ruid}"
    fi
    systemctl --user "$@"
    return
  fi
  local uid
  uid="$(id -u "${TARGET_USER}")"
  [[ -d "/run/user/${uid}" ]] \
    || install -d -o "${TARGET_USER}" -g "$(id -gn "${TARGET_USER}")" -m 0700 "/run/user/${uid}" 2>/dev/null || true
  if ! systemctl is-active "user@${uid}.service" >/dev/null 2>&1; then
    loginctl enable-linger "${TARGET_USER}" 2>/dev/null || true
    systemctl start "user@${uid}.service" 2>/dev/null || true
  fi
  runuser -u "${TARGET_USER}" -- env XDG_RUNTIME_DIR="/run/user/${uid}" \
    XDG_CONFIG_HOME="${TARGET_HOME}/.config" systemctl --user "$@"
}

# nwg-hello reads everything (niri session, css, background, user list) from
# /etc/nwg-hello, so the repository copy is the source of truth.
deploy_nwg_hello() {
  local src="${CONFIG_DIR}/etc/nwg-hello" f
  local files=()
  [[ -d "${src}" ]] || die "missing ${src}; the greeter has no configuration"
  shopt -s nullglob
  files=("${src}/"*)
  shopt -u nullglob
  (( ${#files[@]} > 0 )) || die "${src} is empty; the greeter has no configuration"
  run install -d -o root -g root -m 0755 "${NWG_HELLO_DIR}"
  for f in "${files[@]}"; do
    [[ -f "${f}" ]] || continue
    run install -o root -g root -m 0644 "${f}" "${NWG_HELLO_DIR}/${f##*/}"
  done
  log "Deployed ${#files[@]} nwg-hello file(s)"
}

section "User services"

userctl daemon-reload >/dev/null 2>&1 || warn "user daemon-reload failed"

if [[ "${DESKTOP_ENV}" == "none" ]]; then
  # TTY login: undo an earlier desktop install, best effort.
  run systemctl disable greetd >/dev/null 2>&1 || warn "could not disable greetd.service"
  log "Desktop services disabled (${DESKTOP_ENV})"
else
  # greetd starts niri on vt 1 from /etc/nwg-hello/niri.kdl and nwg-hello runs
  # inside it. A missing payload or unit leaves no GUI.
  deploy_nwg_hello
  getent passwd "${GREETER_USER}" >/dev/null 2>&1 \
    || run useradd --system --home-dir / --shell /bin/bash "${GREETER_USER}" \
    || die "could not create greeter user ${GREETER_USER}"
  run install -d -o root -g root -m 0755 /etc/greetd
  printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "niri -c /etc/nwg-hello/niri.kdl"\nuser = "%s"\n' \
    "${GREETER_USER}" | run tee /etc/greetd/config.toml >/dev/null
  run systemctl enable greetd >/dev/null 2>&1 || die "could not enable greetd.service"
  log "Service: greetd"

  # Units deployed by the config step (vellum, obsidian-sync, ...). A service
  # without [Install] is driven by its timer, so staying disabled is fine.
  for u in "${TARGET_HOME}/.config/systemd/user/"*.service "${TARGET_HOME}/.config/systemd/user/"*.timer; do
    [[ -e "${u}" ]] || continue
    if userctl enable "${u##*/}" >/dev/null 2>&1; then
      log "User unit: ${u##*/}"
    elif grep -q '^\[Install\]' "${u}"; then
      warn "could not enable user unit: ${u##*/}"
    else
      log "User unit: ${u##*/} (no [Install]; driven by another unit)"
    fi
  done
fi

section "System services"

run systemctl daemon-reload >/dev/null 2>&1 || warn "system daemon-reload failed"

# Same set on every machine type; NetworkManager is the one that must not fail.
SERVICES=(bluetooth.service docker.service NetworkManager.service \
          grub-btrfsd.service systemd-timesyncd.service lm_sensors.service)
for s in "${SERVICES[@]}"; do
  if run systemctl enable --now "${s}" >/dev/null 2>&1; then
    log "Service: ${s}"
  elif [[ "${s}" == "NetworkManager.service" ]]; then
    die "could not enable ${s} (required for networking)"
  else
    warn "could not enable ${s}"
  fi
done

# snapper-timeline is what actually creates the TIMELINE_CREATE snapshots.
for t in snapper-cleanup.timer snapper-timeline.timer; do
  if run systemctl enable --now "${t}" >/dev/null 2>&1; then
    log "Timer: ${t}"
  else
    warn "could not enable ${t}"
  fi
done

# btrfs scrub timer: only meaningful on a btrfs root.
if [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == "btrfs" ]] \
   && systemctl list-unit-files 'btrfs-scrub@.timer' >/dev/null 2>&1; then
  run systemctl enable --now 'btrfs-scrub@-.timer' >/dev/null 2>&1 \
    || warn "could not enable btrfs-scrub@-.timer"
fi

section "User groups"

# 'docker' makes the daemon usable without sudo after the next login.
if ! getent group docker >/dev/null 2>&1; then
  run groupadd docker 2>/dev/null || warn "could not create group docker"
fi
if ! id -nG "${TARGET_USER}" 2>/dev/null | grep -qw docker; then
  if run usermod -aG docker "${TARGET_USER}" 2>/dev/null; then
    log "Added ${TARGET_USER} to group docker"
  else
    warn "could not add ${TARGET_USER} to group docker"
  fi
fi

section "GRUB theme"

GRUB_THEME_DIR=/boot/grub/themes/Elegant-mountain-blur-left-dark
log "Deploying GRUB theme (${GRUB_THEME_DIR})"
# cp -r, not -a: /boot is often a vfat ESP that cannot preserve ownership.
run bash -c "mkdir -p /boot/grub/themes && cp -r '${CONFIG_DIR}/etc/grub/themes/Elegant-mountain-blur-left-dark' /boot/grub/themes/"

if [[ ! -f /etc/default/grub ]]; then
  warn "/etc/default/grub missing; GRUB theme not configured"
else
  grep -q '^GRUB_THEME=' /etc/default/grub \
    || printf 'GRUB_THEME="%s/theme.txt"\n' "${GRUB_THEME_DIR}" | run tee -a /etc/default/grub >/dev/null
  # The legacy GRUB_TERMINAL overrides the output, and the theme is only
  # applied on gfxterm.
  run sed -i '/^GRUB_TERMINAL=/d' /etc/default/grub
  if grep -q '^GRUB_TERMINAL_OUTPUT=' /etc/default/grub; then
    grep -q '^GRUB_TERMINAL_OUTPUT="gfxterm"' /etc/default/grub \
      || run sed -i 's|^GRUB_TERMINAL_OUTPUT=.*|GRUB_TERMINAL_OUTPUT="gfxterm"|' /etc/default/grub
  else
    printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\n' | run tee -a /etc/default/grub >/dev/null
  fi
fi

if command -v grub-mkconfig >/dev/null 2>&1; then
  run cp -f /boot/grub/grub.cfg "/boot/grub/grub.cfg.bak-$(date +%Y%m%d%H%M%S)" 2>/dev/null \
    || warn "could not back up /boot/grub/grub.cfg"
  if run grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
    success "GRUB theme applied (grub.cfg regenerated)"
  else
    warn "grub-mkconfig failed; run it manually"
  fi
else
  warn "grub-mkconfig not found; theme not regenerated"
fi

log "Deploying paru.conf"
run install -o root -g root -m 0644 "${CONFIG_DIR}/etc/paru.conf" /etc/paru.conf

success "Service configuration complete"
