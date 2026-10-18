#!/usr/bin/env bash
# 03-drivers.sh — GPU and platform drivers.
# supergfxctl comes from archlinuxcn, which step 02 configures.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

MANIFEST="${MANIFESTS_DIR}/workstation-packages.tsv"
DRIVER_MODULES=" graphics-amd graphics-nvidia hardware-tools asus-hardware "
REQUIRED_MODULES=" graphics-amd graphics-nvidia asus-hardware "

section "GPU and platform drivers (physical)"

REQUIRED=()
OPTIONAL=()
while IFS=$'\t' read -r pkg _channel _repo _acq module _restore policy _origin _purpose; do
  [[ -z "${pkg}" || "${pkg}" == "#"* ]] && continue
  [[ "${policy}" == "verify" || "${policy}" == "deferred" ]] && continue
  [[ "${DRIVER_MODULES}" == *" ${module} "* ]] || continue
  if [[ "${REQUIRED_MODULES}" == *" ${module} "* ]]; then
    REQUIRED+=("${pkg}")
  else
    OPTIONAL+=("${pkg}")
  fi
done < "${MANIFEST}"

if (( ${#REQUIRED[@]} == 0 && ${#OPTIONAL[@]} == 0 )); then
  warn "no driver packages selected; continuing"
  exit 0
fi

# A desktop cannot render without working GPU drivers, so required modules
# abort the install; hardware-tools are conveniences and only warn.
if (( ${#REQUIRED[@]} > 0 )); then
  log "Required drivers (${#REQUIRED[@]}): ${REQUIRED[*]}"
  run pacman -S --needed --noconfirm "${REQUIRED[@]}" \
    || die "required driver install failed; the desktop cannot render without working GPU drivers"
fi

if (( ${#OPTIONAL[@]} > 0 )); then
  log "Optional hardware tools (${#OPTIONAL[@]}): ${OPTIONAL[*]}"
  run pacman -S --needed --noconfirm "${OPTIONAL[@]}" || warn "optional hardware tools failed; continuing"
fi

# asusd.service is static and pulled in by supergfxd, so only supergfxd is
# enabled, and it must come up on a physical ASUS machine.
log "Enabling supergfxd"
run systemctl daemon-reload
run systemctl enable --now supergfxd || die "could not enable supergfxd (required on this ASUS machine)"

success "Drivers installed (${#REQUIRED[@]} required, ${#OPTIONAL[@]} optional)"
log "NVIDIA DKMS modules need a reboot; pick the GPU mode afterwards with: supergfxctl -m Hybrid (or Integrated/dGPU)"
