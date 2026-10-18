#!/usr/bin/env bash
# 01-system.sh — mirrorlist + full system upgrade + base build tools.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

section "Mirror and system upgrade"

# Prefer fast China mirrors when reachable; keep the existing list otherwise.
MIRRORS=(
  "https://mirrors.tuna.tsinghua.edu.cn/archlinux"
  "https://mirrors.ustc.edu.cn/archlinux"
  "https://mirrors.aliyun.com/archlinux"
  "https://mirrors.cloud.tencent.com/archlinux"
  "https://mirrors.huaweicloud.com/archlinux"
  "https://mirrors.163.com/archlinux"
  "https://mirrors.lzu.edu.cn/archlinux"
  "https://mirrors.zju.edu.cn/archlinux"
)
reachable=0
for base in "${MIRRORS[@]:0:3}"; do
  if curl -fsS --connect-timeout 4 --max-time 8 -o /dev/null "${base}/core/os/x86_64/core.db" 2>/dev/null; then
    reachable=1
    break
  fi
done

if (( reachable )); then
  log "Writing China mirror list (${#MIRRORS[@]} mirrors)"
  run bash -c 'cat > /etc/pacman.d/mirrorlist <<"EOF"
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch
Server = https://mirrors.cloud.tencent.com/archlinux/$repo/os/$arch
Server = https://mirrors.huaweicloud.com/archlinux/$repo/os/$arch
Server = https://mirrors.163.com/archlinux/$repo/os/$arch
Server = https://mirrors.lzu.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.zju.edu.cn/archlinux/$repo/os/$arch
EOF'
  success "China mirror list written"
elif command -v reflector >/dev/null 2>&1; then
  log "No China mirror reachable; running reflector (60s cap)"
  run timeout 60 reflector --protocol https -a 5 -f 3 --sort rate --save /etc/pacman.d/mirrorlist \
    && success "reflector finished" || warn "reflector failed; keeping existing mirrorlist"
else
  warn "No China mirror reachable and reflector not installed; keeping existing mirrorlist"
fi

# multilib is needed for the lib32 packages in the manifest.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  log "Enabling multilib..."
  run sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

# Single owner of the official database refresh/upgrade.
if [[ "${FORCE_REFRESH:-0}" == "1" ]]; then
  log "pacman -Syyu (repair mode)"
  run pacman -Syyu --noconfirm
else
  log "pacman -Syu"
  run pacman -Syu --noconfirm
fi

log "Installing base build tools..."
run pacman -S --needed --noconfirm base-devel git python curl
success "System up to date"
