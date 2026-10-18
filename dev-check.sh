#!/usr/bin/env bash
# dev-check.sh — minimal pre-commit check: syntax, executability, CLI.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

fail=0
shopt -s nullglob
for f in install.sh strap.sh dev-check.sh lib/*.sh steps/*.sh; do
  bash -n "${f}" || { echo "syntax error: ${f}"; fail=1; }
done
for step in steps/*.sh; do
  [[ -x "${step}" ]] || { echo "not executable: ${step}"; fail=1; }
done
./install.sh --help >/dev/null || { echo "install.sh --help failed"; fail=1; }
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S error install.sh lib/*.sh steps/*.sh || fail=1
fi
(( fail == 0 )) && echo "dev-check: OK"
exit "${fail}"
