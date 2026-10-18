#!/usr/bin/env bash
# 06-config.sh — deploy the operator's configuration files into the target HOME.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

MAPPINGS="${MAPPINGS:-${MANIFESTS_DIR}/config-mappings.tsv}"
CONFIG_SRC="${CONFIG_SRC:-${CONFIG_DIR}}"
SCOPE="physical-v1"
DESKTOP_ENV="${DESKTOP_ENV:-niri}"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"
BACKUP_DIR="${TARGET_HOME}/.config-backup-my-arch-$(date +%Y%m%d%H%M%S)"

section "Deploying config mappings (scope: ${SCOPE}, target: ${TARGET_USER})"

[[ -f "${MAPPINGS}" ]] || die "missing ${MAPPINGS}"
mkdir -p "${BACKUP_DIR}"
log "Backup directory: ${BACKUP_DIR}"

deployed=0
skipped=0

deploy_one() { # deploy_one <repo-relative source> <HOME-relative target> <mode>
  local src="$1" tgt="$2" mode="$3"
  local local_src="${CONFIG_SRC}/${src#config/}"
  local target="${TARGET_HOME}/${tgt}"

  if [[ ! -f "${local_src}" ]]; then
    warn "source missing: ${src}"
    skipped=$((skipped + 1))
    return 0
  fi
  # An absolute target or one containing ".." would escape HOME.
  case "${tgt}" in
    /*|*".."*)
      warn "refusing ${tgt}: target escapes HOME"
      skipped=$((skipped + 1))
      return 0
      ;;
  esac

  # Back up the target as it is, including a symlink itself rather than what
  # it points at.
  if [[ -e "${target}" || -L "${target}" ]]; then
    mkdir -p "${BACKUP_DIR}/$(dirname "${tgt}")"
    cp -aP "${target}" "${BACKUP_DIR}/${tgt}" 2>/dev/null \
      || warn "backup of ${tgt} failed; overwriting without a copy"
  fi
  if [[ -L "${target}" ]]; then
    rm -f "${target}"
  fi

  mkdir -p "$(dirname "${target}")"
  cp -a "${local_src}" "${target}"
  chmod "${mode}" "${target}" 2>/dev/null || warn "could not chmod ${mode} ${target}"

  # On the root path the directories belong to root; the target user must own
  # the file and its path so later user-run steps can write there.
  if [[ "$(id -u)" -eq 0 ]]; then
    local dir="${target}"
    while [[ "${dir}" == "${TARGET_HOME}"/* ]]; do
      chown "${TARGET_USER}:${TARGET_GROUP}" "${dir}" 2>/dev/null || true
      dir="$(dirname "${dir}")"
    done
  fi

  deployed=$((deployed + 1))
}

while IFS=$'\t' read -r scope module src tgt mode; do
  [[ -z "${src}" || "${src}" == "#"* ]] && continue
  [[ "${scope}" == "${SCOPE}" ]] || continue
  module_selected "${module}" config || continue
  deploy_one "${src}" "${tgt}" "${mode}"
done < "${MAPPINGS}"

log "Deployed: ${deployed} file(s), skipped: ${skipped}"

# The backup tree was created by root on the root path; hand it over so it can
# be inspected or removed without sudo.
if [[ "$(id -u)" -eq 0 && -d "${BACKUP_DIR}" ]]; then
  chown -R "${TARGET_USER}:${TARGET_GROUP}" "${BACKUP_DIR}" 2>/dev/null || true
fi

# Regenerate the niri VM test config (keybinds off, switch key kept) so the
# toggle in config.kdl never points at a missing file.
if [[ "${DESKTOP_ENV}" != "none" ]] \
   && [[ -f "${TARGET_HOME}/.config/niri/scripts/niri-vmtest-gen" ]] \
   && [[ -f "${TARGET_HOME}/.config/niri/config.kdl" ]]; then
  as_user bash "${TARGET_HOME}/.config/niri/scripts/niri-vmtest-gen" \
    || warn "niri-vmtest-gen failed; VM test config not generated"
  if [[ -f "${TARGET_HOME}/.config/niri/config.kdl.vmtest" ]]; then
    log "niri VM test config present: config.kdl.vmtest"
  else
    warn "niri config.kdl.vmtest missing after generation"
  fi
  if command -v niri >/dev/null 2>&1; then
    if niri validate -c "${TARGET_HOME}/.config/niri/config.kdl" >/dev/null 2>&1 \
       && niri validate -c "${TARGET_HOME}/.config/niri/config.kdl.vmtest" >/dev/null 2>&1; then
      log "niri validate: normal + vmtest configs both OK"
    else
      warn "niri validate failed for normal or vmtest config"
    fi
  fi
fi

# ${HOME}/.local/bin entry points that the configs call as bare commands.
if [[ "${DESKTOP_ENV}" != "none" ]]; then
  local_bin="${TARGET_HOME}/.local/bin"
  mkdir -p "${local_bin}"
  if [[ "$(id -u)" -eq 0 ]]; then
    chown "${TARGET_USER}:${TARGET_GROUP}" "${local_bin}" 2>/dev/null || true
  fi
  while IFS='|' read -r link_name script_rel; do
    [[ -z "${link_name}" ]] && continue
    target="${TARGET_HOME}/scripts/${script_rel}"
    link_path="${local_bin}/${link_name}"
    if [[ ! -f "${target}" ]]; then
      warn "${script_rel} not deployed; skipping ${link_name}"
    elif [[ -L "${link_path}" ]]; then
      if [[ "$(readlink "${link_path}")" != "${target}" ]]; then
        ln -sfn "${target}" "${link_path}" && log "refreshed ${link_name} -> ${target}"
      fi
    elif [[ -e "${link_path}" ]]; then
      warn "${link_path} exists as a regular file; not overwriting"
    else
      ln -s "${target}" "${link_path}" && log "${link_name} -> ${target}"
    fi
  done <<'ENTRIES'
b23|media/b23
gsudo|desktop/gsudo
fuzzel-askpass|desktop/fuzzel-askpass
ENTRIES
fi

success "Config deployment complete (backup in ${BACKUP_DIR})"
