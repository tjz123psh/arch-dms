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
# enabled. Starting it is best-effort: on a VM the unit exists but there is no
# ASUS hardware, and a failed start must not abort the installation.
log "Enabling supergfxd"
run systemctl daemon-reload
run systemctl enable supergfxd || die "could not enable supergfxd"
run systemctl start supergfxd 2>/dev/null \
  || warn "supergfxd did not start (no ASUS hardware?); it will retry at boot"

success "Drivers installed (${#REQUIRED[@]} required, ${#OPTIONAL[@]} optional)"
log "NVIDIA DKMS modules need a reboot; pick the GPU mode afterwards with: supergfxctl -m Hybrid (or Integrated/dGPU)"
