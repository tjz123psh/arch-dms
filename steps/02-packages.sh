#!/usr/bin/env bash
# 02-packages.sh — install every selected manifest package that lives in an
# official or archlinuxcn repository. AUR packages are installed in step 05.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

MANIFEST="${MANIFESTS_DIR}/workstation-packages.tsv"

section "Packages (${MACHINE_TYPE:-physical}, desktop=${DESKTOP_ENV:-niri})"

OFFICIAL=()
AUR_COUNT=0
HAVE_ARCHLINUXCN=false
# module_selected() owns the machine/desktop filtering (hardware modules are
# step 03's; desktop modules follow DESKTOP_ENV).
while IFS=$'\t' read -r pkg channel repo _acq module _restore policy _origin _purpose; do
  [[ -z "${pkg}" || "${pkg}" == "#"* ]] && continue
  [[ "${policy}" == "verify" || "${policy}" == "deferred" ]] && continue
  module_selected "${module}" || continue
  case "${channel}" in
    pacman) OFFICIAL+=("${pkg}") ;;
    aur)    AUR_COUNT=$((AUR_COUNT + 1)) ;;
  esac
  [[ "${repo}" == "archlinuxcn" ]] && HAVE_ARCHLINUXCN=true
done < "${MANIFEST}"
log "${#OFFICIAL[@]} official/archlinuxcn package(s) selected, ${AUR_COUNT} AUR package(s) left to step 05"

# archlinuxcn packages live outside the official repos, so the repository and
# its keyring must exist before the batch. Exactly one database sync after the
# block, which also covers a resumed run where the keyring is already present.
if [[ "${HAVE_ARCHLINUXCN}" == "true" ]]; then
  if ! grep -q '^\[archlinuxcn\]' /etc/pacman.conf; then
    log "Adding [archlinuxcn] to /etc/pacman.conf"
    run bash -c 'cat >> /etc/pacman.conf <<"EOF"
[archlinuxcn]
Server = https://mirrors.aliyun.com/archlinuxcn/$arch
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
Server = https://mirrors.cloud.tencent.com/archlinuxcn/$arch
Server = https://mirrors.huaweicloud.com/archlinuxcn/$arch
Server = https://mirrors.lzu.edu.cn/archlinuxcn/$arch
Server = https://mirrors.zju.edu.cn/archlinuxcn/$arch
EOF'
  fi
  log "Syncing databases (pacman -Sy)"
  run pacman -Sy --noconfirm || die "pacman -Sy failed; cannot reach the archlinuxcn repository"
  if ! pacman -Q archlinuxcn-keyring >/dev/null 2>&1; then
    log "Installing archlinuxcn-keyring"
    run pacman -S --needed --noconfirm archlinuxcn-keyring \
      || die "archlinuxcn-keyring install failed; archlinuxcn packages cannot be installed"
  fi
fi

# The archlinuxcn builds replace the old AUR packages of the same app under a
# different name and conflict with them; --noconfirm answers that prompt by
# aborting the whole transaction, so drop the legacy package first.
for pair in flclash:flclash-bin clash-verge-rev:clash-verge-rev-bin; do
  target="${pair%%:*}"
  legacy="${pair##*:}"
  [[ " ${OFFICIAL[*]} " == *" ${target} "* ]] || continue
  pacman -Q "${legacy}" >/dev/null 2>&1 || continue
  log "Replacing ${legacy} (AUR) with ${target}"
  run pacman -R --noconfirm "${legacy}" \
    || die "could not remove ${legacy}; ${target} cannot be installed while it is present"
done

# rustup conflicts with rust/cargo/rustfmt but provides them. Install it before
# the batch so packages depending on cargo resolve against rustup instead of
# pulling the conflicting rust package; clear a partial install first.
if [[ " ${OFFICIAL[*]} " == *" rustup "* ]]; then
  for p in rust cargo rustfmt; do
    pacman -Q "${p}" >/dev/null 2>&1 || continue
    log "Removing ${p} (rustup provides it)"
    run pacman -Rdd --noconfirm "${p}" 2>/dev/null || warn "could not remove ${p}; continuing"
  done
  run pacman -S --needed --noconfirm rustup || die "rustup install failed; cargo packages cannot be installed"
fi

if (( ${#OFFICIAL[@]} > 0 )); then
  log "Installing ${#OFFICIAL[@]} package(s)..."
  if ! run pacman -S --needed --noconfirm "${OFFICIAL[@]}"; then
    warn "Batch install failed; retrying once (mirror stalls are common)"
    run pacman -S --needed --noconfirm "${OFFICIAL[@]}" \
      || die "official package install failed twice; inspect the pacman output above, then rerun ./install.sh to resume"
  fi
else
  log "No official packages selected for this machine/desktop"
fi

success "Packages installed (${#OFFICIAL[@]} official, ${AUR_COUNT} AUR pending step 05)"
