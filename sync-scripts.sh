#!/usr/bin/env bash
# sync-scripts.sh — copy ~/scripts into config/home/scripts and refresh mappings.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HOME}/scripts"
DEST="${ROOT}/config/home/scripts"

[[ -d "${SRC}" ]] || { echo "error: ${SRC} not found" >&2; exit 1; }

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude='.git/' --exclude='review/' --exclude='review1/' \
    --exclude='.backups/' --exclude='__pycache__/' --exclude='*.pyc' \
    --exclude='*.log' --exclude='*.tar.gz' --exclude='*.bak' \
    --exclude='README*' \
    "${SRC}/" "${DEST}/"
else
  cp -a "${SRC}/." "${DEST}/"
fi

"${ROOT}/sync-config-mappings.sh"

# Drop mapping rows whose source file no longer exists.
python3 - "${ROOT}/manifests/config-mappings.tsv" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
lines = p.read_text().splitlines()
keep = []
for ln in lines:
    if ln and not ln.startswith("#"):
        f = ln.split("\t")
        if len(f) >= 5 and not Path(f[2]).is_file():
            continue
    keep.append(ln)
p.write_text("\n".join(keep) + "\n")
PY

git -C "${ROOT}" diff --stat config/home/scripts manifests/config-mappings.tsv
