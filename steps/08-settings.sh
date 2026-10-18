#!/usr/bin/env bash
# 08-settings.sh — locale, timezone, hostname, swap and snapper settings.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

TARGET_GROUP="$(id -gn "${TARGET_USER}")"

section "System settings"

# --- locale ---
log "Configuring locale (zh_CN.UTF-8, en_US.UTF-8)"
# A minimal locale.gen may not list either locale at all: uncomment the lines
# when present, append what is missing.
run bash -c '
  sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/; s/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/" /etc/locale.gen
  grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen || echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
'
run locale-gen
run bash -c 'printf "LANG=zh_CN.UTF-8\nLC_CTYPE=en_US.UTF-8\n" > /etc/locale.conf'
success "Locale: LANG=zh_CN.UTF-8, LC_CTYPE=en_US.UTF-8"

# --- timezone ---
log "Setting timezone to Asia/Shanghai"
run ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
run bash -c 'printf "Asia/Shanghai\n" > /etc/timezone'
success "Timezone: Asia/Shanghai"

# --- hostname ---
if [[ -s /etc/hostname ]]; then
  log "Hostname already set: $(cat /etc/hostname)"
else
  log "Setting hostname to archlinux"
  run bash -c 'printf "archlinux\n" > /etc/hostname'
fi

# --- zram swap ---
if ! pacman -Q zram-generator >/dev/null 2>&1; then
  log "Installing zram-generator"
  run pacman -S --needed --noconfirm zram-generator
fi
run bash -c 'cat > /etc/systemd/zram-generator.conf <<"EOF"
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF'
run systemctl daemon-reload
success "zram configured (zstd, size=ram)"

# --- standard user directories ---
log "Creating standard user directories"
STD_DIRS=(Desktop Documents Downloads Music Public Templates Videos)
if [[ "$(id -u)" -eq 0 ]]; then
  for d in "${STD_DIRS[@]}"; do
    mkdir -p "${TARGET_HOME}/${d}"
    chown "${TARGET_USER}:${TARGET_GROUP}" "${TARGET_HOME}/${d}"
  done
else
  for d in "${STD_DIRS[@]}"; do
    mkdir -p "${HOME}/${d}"
  done
fi

# --- login shell ---
if command -v fish >/dev/null 2>&1; then
  if ! grep -qx '/usr/bin/fish' /etc/shells; then
    run bash -c 'echo /usr/bin/fish >> /etc/shells'
  fi
  if [[ "$(getent passwd "${TARGET_USER}" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    log "Setting login shell for ${TARGET_USER} to fish"
    run chsh -s /usr/bin/fish "${TARGET_USER}" || warn "could not set fish as login shell"
  fi
fi

# --- Nautilus file manager settings ---
# Nautilus preferences live in dconf; the dump is part of the config payload.
# A private session bus lets dconf write ~/.config/dconf/user without a login.
nautilus_dconf="${TARGET_HOME}/.config/nautilus/nautilus.dconf"
if [[ -f "${nautilus_dconf}" ]]; then
  if command -v dconf >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
    log "Loading Nautilus settings (dconf)"
    if [[ "$(id -u)" -eq 0 ]]; then
      runuser -u "${TARGET_USER}" -- env HOME="${TARGET_HOME}" \
        dbus-run-session -- dconf load /org/gnome/nautilus/ < "${nautilus_dconf}" >/dev/null \
        || warn "could not load Nautilus dconf settings (load them manually after login)"
    else
      dbus-run-session -- dconf load /org/gnome/nautilus/ < "${nautilus_dconf}" >/dev/null \
        || warn "could not load Nautilus dconf settings (load them manually after login)"
    fi
  else
    warn "dconf/dbus-run-session missing; Nautilus settings not loaded"
  fi
fi

# --- snapper configs ---
# 07 enables snapper-cleanup.timer; the snapshot tooling expects root and home
# configs, with wheel able to read the .snapshots subvolumes.
if command -v snapper >/dev/null 2>&1 && command -v btrfs >/dev/null 2>&1; then
  if [[ ! -f /etc/snapper/configs/root ]]; then
    log "Initializing snapper root config"
    run rmdir /.snapshots 2>/dev/null || true
    run snapper -c root create-config / || {
      warn "snapper root config failed; snapshots unavailable"
      run mkdir -p /.snapshots
    }
  fi
  if [[ ! -f /etc/snapper/configs/home ]]; then
    log "Initializing snapper home config"
    run rmdir /home/.snapshots 2>/dev/null || true
    run snapper -c home create-config /home || {
      warn "snapper home config failed; home snapshots unavailable"
      run mkdir -p /home/.snapshots
    }
  fi
  for conf in root home; do
    if [[ -f "/etc/snapper/configs/${conf}" ]]; then
      run snapper -c "${conf}" set-config ALLOW_GROUPS=wheel SYNC_ACL=yes || true
    fi
  done
  # wheel reads .snapshots through an ACL; never widen it to world-readable
  # (snapshots contain every user's files).
  run setfacl -m g:wheel:r-x /.snapshots 2>/dev/null || true
  run setfacl -m g:wheel:r-x /home/.snapshots 2>/dev/null || true
fi

success "System settings complete"
