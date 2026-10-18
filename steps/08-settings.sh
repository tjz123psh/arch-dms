#!/usr/bin/env bash
# 08-settings.sh — locale, timezone, hostname, swap and desktop-side caches.
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
STD_DIRS=(Desktop Documents Downloads Music Pictures Public Templates Videos)
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

# --- dms plugin dependencies ---
# The dankmaintenance and ShorinScreenrec plugins test these paths at startup
# and report a failed load when they are missing.
log "Creating dms plugin dependency paths"
mkdir -p "${TARGET_HOME}/.cache/checkallupdates"
run mkdir -p /.snapshots /home/.snapshots
menu_src="${CONFIG_DIR}/home/.local/bin/shorin-screenrec-menu"
# Installed system-wide because the plugin's startup check runs with a PATH
# that does not include ~/.local/bin.
if [[ -f "${menu_src}" ]]; then
  run install -m 755 "${menu_src}" /usr/local/bin/shorin-screenrec-menu
  log "Deployed shorin-screenrec-menu to /usr/local/bin"
else
  warn "shorin-screenrec-menu missing from config; ShorinScreenrec may fail its startup check"
fi

# Recording engine: wf-recorder works on every machine (CPU encoding, rebuilt
# against the current ffmpeg). Physical GPUs get h264_vaapi; the probe encodes
# one frame and falls back to libx264 on any failure.
log "Presetting screen recording engine"
rec_dir="${TARGET_HOME}/.cache/shorin-screenrec"
mkdir -p "${rec_dir}"
printf 'wf-recorder\n' > "${rec_dir}/engine"
printf 'preset=fast:crf=18\n' > "${rec_dir}/enc_params_wf"
codec="libx264"
if [[ -e /dev/dri/renderD128 ]] && command -v ffmpeg >/dev/null 2>&1; then
  if ffmpeg -hide_banner -loglevel error -f lavfi -i color=black:s=128x128:d=0.1 \
      -vf "format=nv12,hwupload" -c:v h264_vaapi -vaapi_device /dev/dri/renderD128 \
      -f null - >/dev/null 2>&1; then
    codec="h264_vaapi"
  fi
fi
printf '%s\n' "${codec}" > "${rec_dir}/codec_wf"

# On the root path mkdir -p leaves the whole chain root-owned; the first
# desktop session must be able to write its caches and recording settings.
if [[ "$(id -u)" -eq 0 ]]; then
  chown "${TARGET_USER}:${TARGET_GROUP}" \
    "${TARGET_HOME}/.cache" "${TARGET_HOME}/.cache/checkallupdates" "${rec_dir}" \
    "${rec_dir}/engine" "${rec_dir}/enc_params_wf" "${rec_dir}/codec_wf" 2>/dev/null || true
fi
log "Recording engine: $(cat "${rec_dir}/engine") codec: $(cat "${rec_dir}/codec_wf") params: $(cat "${rec_dir}/enc_params_wf")"

# --- snapper configs ---
# 07 enables snapper-cleanup.timer; the snapshot tooling and dms plugins expect
# root and home configs, with wheel able to read the .snapshots subvolumes.
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
