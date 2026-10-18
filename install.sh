#!/usr/bin/env bash
# install.sh — restore the operator's Arch desktop from this repository.
#
#   select desktop -> run the steps in order -> reboot prompt
#
# Re-running resumes after the last completed step; delete .install-progress
# to start from the beginning.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT}/lib/common.sh"

PROGRESS_FILE="${ROOT}/.install-progress"
SUDOERS_DROPIN=/etc/sudoers.d/99-install-nopasswd
STEPS=(
  01-system.sh
  02-packages.sh
  03-drivers.sh
  04-desktop.sh
  05-aur.sh
  06-config.sh
  07-services.sh
  08-settings.sh
)

DESKTOP_ENV="${DESKTOP_ENV:-}"
ASSUME_YES=false
FORCE_REFRESH="${FORCE_REFRESH:-0}"
FZF_OK=1

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  -d, --desktop niri|none        niri | no desktop
  -r, --force-refresh            repair mode: pacman -Syyu instead of -Syu
  -y, --assume-yes               reboot without asking at the end
  -h, --help
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      -d|--desktop)  DESKTOP_ENV="${2:?missing value for --desktop}"; shift 2 ;;
      -r|--force-refresh) FORCE_REFRESH=1; shift ;;
      -y|--assume-yes)    ASSUME_YES=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1 (see --help)" ;;
    esac
  done
}

# fzf when available; numbered prompt otherwise (a fresh base has no fzf).
pick_numbered() { # pick_numbered <prompt> <option>...
  local prompt="$1"; shift
  local i=1 opt choice
  for opt in "$@"; do printf '%d) %s\n' "${i}" "${opt}" >&2; i=$((i + 1)); done
  printf '%s [1-%d]: ' "${prompt}" "$#" >&2
  read -r choice || die "no input"
  [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= $# )) || die "invalid choice: ${choice}"
  echo "${choice}"
}

pick() { # pick <header> <option>... -> prints the selected option
  local header="$1"; shift
  if (( FZF_OK )); then
    local out
    out="$(printf '%s\n' "$@" | fzf --layout=reverse --border=rounded \
      --header=" ${header} " --bind 'j:down,k:up,esc:abort,ctrl-c:abort')" || true
    [[ -n "${out}" ]] || die "selection cancelled"
    echo "${out}"
  else
    local n
    n="$(pick_numbered "${header}" "$@")" || exit 1
    shift $((n - 1))
    echo "$1"
  fi
}

select_desktop() {
  [[ -n "${DESKTOP_ENV}" ]] && return
  local sel
  sel="$(pick "Select desktop" "Niri (recommended)" "No desktop (packages and config only)")"
  case "${sel}" in
    No*) DESKTOP_ENV=none ;;
    *)   DESKTOP_ENV=niri ;;
  esac
  log "Desktop: ${DESKTOP_ENV}"
}

# --- resume state -----------------------------------------------------------
# A plain list of finished steps. The header binds it to the desktop choice,
# so a stale file from a different selection starts over instead of silently
# skipping steps.
progress_begin() {
  local ctx="desktop=${DESKTOP_ENV}"
  if [[ -f "${PROGRESS_FILE}" ]]; then
    if [[ "$(head -1 "${PROGRESS_FILE}")" == "# context: ${ctx}" ]]; then
      log "Resuming (finished: $(grep -v '^#' "${PROGRESS_FILE}" | tr '\n' ' '))"
      return
    fi
    warn "progress file belongs to another install; starting over"
    rm -f "${PROGRESS_FILE}"
  fi
  printf '# context: %s\n' "${ctx}" > "${PROGRESS_FILE}"
}

is_done() { grep -qx "$1" "${PROGRESS_FILE}" 2>/dev/null; }
mark_done() { echo "$1" >> "${PROGRESS_FILE}"; }

# --- sudo -------------------------------------------------------------------
# makepkg runs every pacman call as 'sudo -k', which clears the timestamp; a
# scoped NOPASSWD for pacman keeps the AUR step prompt-free. Removed on every
# exit path.
cleanup_sudoers() {
  [[ -f "${SUDOERS_DROPIN}" ]] || return 0
  if [[ "$(id -u)" -eq 0 ]]; then rm -f "${SUDOERS_DROPIN}"; else sudo rm -f "${SUDOERS_DROPIN}" 2>/dev/null || true; fi
}
trap cleanup_sudoers EXIT

setup_sudo() {
  local line="${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/bin/pacman"
  if [[ "$(id -u)" -eq 0 ]]; then
    printf 'Defaults timestamp_timeout=240\n%s\n' "${line}" > "${SUDOERS_DROPIN}"
  else
    printf 'Defaults timestamp_timeout=240\n%s\n' "${line}" | sudo tee "${SUDOERS_DROPIN}" >/dev/null
  fi
  run chmod 440 "${SUDOERS_DROPIN}"
  run visudo -cf "${SUDOERS_DROPIN}" >/dev/null || die "invalid sudoers drop-in"
  log "Scoped sudo grant active (pacman only)"
}

dashboard() {
  section "System"
  echo "  Kernel  : $(uname -r)"
  echo "  User    : ${TARGET_USER} (${TARGET_HOME})"
  echo "  Desktop : ${DESKTOP_ENV}"
  echo "  Steps   : ${#STEPS[@]}"
}

main() {
  parse_args "$@"
  if [[ -z "${DESKTOP_ENV}" ]]; then
    command -v fzf >/dev/null 2>&1 || { FZF_OK=0; log "fzf not installed; using numbered prompts"; }
  fi
  select_desktop
  case "${DESKTOP_ENV}" in niri|none) ;; *) die "invalid --desktop ${DESKTOP_ENV} (niri|none)" ;; esac
  [[ "${TARGET_USER}" == "pang" ]] \
    || warn "TARGET_USER=${TARGET_USER} != pang: parts of the config hardcode /home/pang (see README)"

  export DESKTOP_ENV FORCE_REFRESH
  dashboard
  progress_begin
  setup_sudo

  local i=0 n=${#STEPS[@]} step rc
  for step in "${STEPS[@]}"; do
    i=$((i + 1))
    if is_done "${step}"; then log "skip ${step} (done)"; continue; fi
    section "Step ${i}/${n}" "${step}"
    rc=0
    bash "${ROOT}/steps/${step}" || rc=$?
    (( rc == 0 )) || die "step ${step} failed (exit ${rc}); rerun ./install.sh to resume"
    mark_done "${step}"
  done

  section "Done"
  success "Installation complete; a reboot is recommended."
  if [[ "${ASSUME_YES}" == "true" ]]; then
    log "Rebooting (--assume-yes)..."; sleep 3; run systemctl reboot
  elif [[ -t 0 ]]; then
    printf '%s' 'Reboot now? [Y/n]: '
    local answer; read -r answer
    if [[ -z "${answer}" || "${answer,,}" == y* ]]; then
      log "Rebooting..."; sleep 3; run systemctl reboot
    else
      log "Skipped; run 'sudo systemctl reboot' when ready."
    fi
  else
    log "Non-interactive session; run 'sudo systemctl reboot' when ready."
  fi
}

main "$@"
