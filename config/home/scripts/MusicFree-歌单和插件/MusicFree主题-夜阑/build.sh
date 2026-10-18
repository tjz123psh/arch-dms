#!/usr/bin/env bash
# 夜阑 —— 重建并打包主题
#   ./build.sh                    用当前桌面壁纸/色板重建，并打包到上一级目录
#   ./build.sh --install          重建后顺便（覆盖式）安装到 MusicFree 本地主题目录
#   ./build.sh --theme-dir DIR    对另一份主题副本操作（默认就是本目录）——试跑/CI 用，避免误触交付目录
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/tools/rebuild.py" "$@"
