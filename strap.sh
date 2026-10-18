#!/usr/bin/env bash
# strap.sh — root bootstrap: clone this repository and run install.sh.
#
#   sudo bash strap.sh
#
# The repository is cloned to /opt/arch-dms and install.sh takes over from
# there (it resolves the desktop user via SUDO_USER).
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/tjz123psh/arch-dms.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/arch-dms}"
BRANCH="${BRANCH:-main}"

die() { echo "strap.sh: $*" >&2; exit 1; }

clone_or_update() {
  if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
    echo "==> Cloning ${REPO_URL} into ${INSTALL_DIR} ..."
    if ! git clone --branch "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}" 2>/tmp/strap-git.err; then
      echo "==> ERROR: could not clone ${REPO_URL}" >&2
      sed 's/^/    /' /tmp/strap-git.err >&2 2>/dev/null || true
      echo "    Network problem? Check: curl -m 10 -sI https://github.com" >&2
      echo "    Or bring the repo over on a USB stick and run its install.sh." >&2
      exit 1
    fi
  else
    echo "==> Updating ${INSTALL_DIR} (${BRANCH}) ..."
    if ! git -C "${INSTALL_DIR}" pull --ff-only 2>/tmp/strap-git.err; then
      echo "==> ERROR: could not update ${INSTALL_DIR}" >&2
      sed 's/^/    /' /tmp/strap-git.err >&2 2>/dev/null || true
      exit 1
    fi
  fi
}

main() {
  [[ "$(id -u)" -eq 0 ]] || die "must run as root (e.g. 'sudo bash strap.sh')"
  command -v git >/dev/null 2>&1 || die "git not found; install it first (pacman -S git)."
  clone_or_update
  exec bash "${INSTALL_DIR}/install.sh" "$@"
}

main "$@"
