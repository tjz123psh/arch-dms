#!/usr/bin/env bash
# patch-plugin-preset-suffix.sh —— 清掉 profile 插件补丁里 persona 的
#   `suffix: Your working directory is {{cwd}}.`
#
# 背景：0.2.1-alpha.2 起 prompt 变量只剩 provider/model，`{{cwd}}` 已删除
# （工作目录改由"工作目录服务"提供）。任何还写着这句的 persona prefix/suffix
# 或 preset 的 suffix 字段，都会让提示词组装在**发消息前**直接失败：
#   unknown prompt variable "{{cwd}}" in section "deployment:persona-suffix"
# 插件 `dsh-argp`（1.9.1）自带的 preset 覆盖里带这句（standard/ptc/cordis 三个预设），
# 上游未修 ⇒ **每次装/更新插件（pnpm 重链 node_modules）后都要重跑本脚本**。
# 本机其它同样写法的地方（家层补丁、profile 补丁、ctxopt 预设源文件）2026-10-10 已手工清理，
# 它们不归 pnpm 管、不会被还原。
#
# 用法:
#   patch-plugin-preset-suffix.sh            # 就地删除这些行（幂等）
#   patch-plugin-preset-suffix.sh --check    # 只检查：0=干净 1=有残留
# 环境变量: DSH_PROFILE_DIR（默认 ~/.dsh/profiles/desktop）
set -uo pipefail

PROFILE_DIR="${DSH_PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
NM="$PROFILE_DIR/node_modules"
PATTERN='suffix: Your working directory is {{cwd}}.'

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

files=0; hits=0; fixed=0
while IFS= read -r f; do
  files=$((files+1))
  n=$(grep -c -F "$PATTERN" "$f" 2>/dev/null || true)
  hits=$((hits+n))
  if [ "$CHECK" -eq 0 ] && [ "$n" -gt 0 ]; then
    grep -v -F "$PATTERN" "$f" >"$f.tmp.$$" && mv "$f.tmp.$$" "$f"
    fixed=$((fixed+n))
    printf '  已清理 %s 行: %s\n' "$n" "${f#"$PROFILE_DIR"/}"
  fi
done < <(find "$NM" -maxdepth 3 -name 'cordis.patch.yml' -type f 2>/dev/null)

echo
if [ "$CHECK" -eq 1 ]; then
  if [ "$hits" -eq 0 ]; then
    echo "干净：$files 个插件补丁里 0 处残留（0.2.1-alpha.2 起 {{cwd}} 已不存在）"
    exit 0
  fi
  echo "有残留：$hits 处 / $files 个文件 —— 跑不带 --check 的本脚本清理，然后重启桌面应用"
  exit 1
fi
if [ "$fixed" -eq 0 ]; then
  echo "无需改动：$files 个插件补丁里 0 处残留"
else
  echo "共清理 $fixed 行 —— **重启桌面应用**后生效（预设行在启动时装载）"
fi
