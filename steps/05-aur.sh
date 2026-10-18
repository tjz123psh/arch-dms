#!/usr/bin/env bash
# 05-aur.sh — AUR packages through paru (needs network).
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

RECIPES_DIR="${PROJECT_DIR}/third_party/aur"
BUILD_BASE="${PROJECT_DIR}/.aur-build"

section "AUR packages"

# Targets come from the manifest, filtered by the same module_selected() as the
# pacman steps, so a vm never builds the physical-only host stack. paru itself
# is not an install target: it is the helper and is bootstrapped below.
targets=()
while IFS=$'\t' read -r pkg channel _repo _acq module _restore policy _origin _purpose; do
  [[ -n "${pkg}" && "${pkg}" != "#"* ]] || continue
  [[ "${channel}" == "aur" && "${policy}" == "install" ]] || continue
  [[ "${pkg}" != "paru" ]] || continue
  module_selected "${module}" package || continue
  targets+=("${pkg}")
done < "${MANIFESTS_DIR}/workstation-packages.tsv"

if (( ${#targets[@]} == 0 )); then
  warn "No AUR targets selected; nothing to install"
  exit 0
fi
log "Targets (${#targets[@]}): ${targets[*]}"

# Run a login shell as the target user: paru and makepkg must not build as root,
# and the toolchains live in that user's home/profile.
user_shell() { # user_shell <command string>
  if [[ "$(id -u)" -eq 0 ]]; then
    runuser -u "${TARGET_USER}" -- env "HOME=${TARGET_HOME}" bash -lc "$1"
  else
    bash -lc "$1"
  fi
}

# rustup has no default toolchain until one is set, and makepkg builds as the
# target user, so the toolchain has to be active in that user's environment.
ensure_rust() {
  local active
  active="$(user_shell 'rustup show active-toolchain 2>/dev/null' || true)"
  [[ -z "${active}" ]] || { log "Rust toolchain: ${active}"; return 0; }
  log "No active Rust toolchain; setting stable for ${TARGET_USER}..."
  user_shell 'rustup default stable' >/dev/null || die "cannot activate a Rust toolchain for ${TARGET_USER}"
}

build_paru() {
  local src="${RECIPES_DIR}/paru" work
  [[ -d "${src}" ]] || die "missing paru recipe: ${src}"
  mkdir -p "${BUILD_BASE}"
  work="$(mktemp -d "${BUILD_BASE}/paru.XXXXXX")"
  cp -a "${src}/." "${work}/"
  # GNU cp applies the source directory's ownership to the destination, so the
  # chown must come after the copy or the user build cannot write into it.
  chown_user "${work}"

  log "Building paru from the pinned recipe..."
  user_shell "export PATH=\"\${HOME}/.cargo/bin:\${PATH}\"; cd '${work}' && /usr/bin/makepkg -s --noconfirm" \
    || die "paru build failed (work dir kept at ${work})"

  local -a built=()
  mapfile -t built < <(find "${work}" -maxdepth 1 -name '*.pkg.tar.*' -print | sort)
  (( ${#built[@]} > 0 )) || die "paru build produced no package (work dir kept at ${work})"
  run pacman -U --noconfirm "${built[@]}"
  rm -rf "${work}"
}

# paru: the archlinuxcn package first (02-packages configured the repo), then
# the pinned recipe built with makepkg when that repo is unavailable.
if ! command -v paru >/dev/null 2>&1; then
  log "Installing paru from archlinuxcn..."
  if ! run pacman -S --needed --noconfirm paru; then
    warn "archlinuxcn paru unavailable; building the pinned recipe instead"
    ensure_rust
    build_paru
  fi
fi
command -v paru >/dev/null 2>&1 || die "paru unavailable; cannot install AUR packages"

# Go-built recipes (greetd-dms-greeter-git) fetch modules through GOPROXY.
# proxy.golang.org is unreachable from CN networks and Go hangs instead of
# failing over, so default to a mirror when the environment sets nothing.
export GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"

# Root path: quote the target list once and hand a single command string to the
# user's login shell. paru resolves AUR dependencies itself, so one -S is enough.
quoted=""
for t in "${targets[@]}"; do quoted+="$(printf '%q ' "${t}")"; done

paru_install() {
  if [[ "$(id -u)" -eq 0 ]]; then
    runuser -u "${TARGET_USER}" -- env "HOME=${TARGET_HOME}" "GOPROXY=${GOPROXY}" \
      bash -lc "paru -S --noconfirm --skipreview ${quoted}"
  else
    paru -S --noconfirm --skipreview "${targets[@]}"
  fi
}

log "Installing ${#targets[@]} AUR packages..."
for attempt in 1 2 3; do
  paru_install && break
  (( attempt < 3 )) || die "paru -S failed after 3 attempts; rerun ./install.sh to retry"
  warn "paru -S failed (attempt ${attempt}/3); retrying in 5s"
  sleep 5
done

installed="$(pacman -Qq)"
missing=()
for t in "${targets[@]}"; do
  grep -Fxq "${t}" <<<"${installed}" || missing+=("${t}")
done
(( ${#missing[@]} == 0 )) || die "AUR packages missing after install: ${missing[*]}"

for t in "${targets[@]}"; do
  log "$(pacman -Q "${t}")"
done
success "AUR stage complete: ${#targets[@]} packages installed"
