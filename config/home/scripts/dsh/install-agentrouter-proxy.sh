#!/usr/bin/env bash
# 安装 / 体检 / 卸载 AgentRouter 本地反代（systemd 用户服务）。
#
# 为什么需要它：agentrouter.org 只经 Clash(127.0.0.1:7890) 可达，且 WAF 只认
# Codex 线形头（originator/version/user-agent/session_id/openai-beta）；
# /v1/messages 另补 anthropic-beta。纯透传、不重试（DSH 自己会重试）。
#
#   bash install-agentrouter-proxy.sh             安装或按本脚本口径修复
#   bash install-agentrouter-proxy.sh --check     只读体检：0=一致 1=漂移/故障
#   bash install-agentrouter-proxy.sh --dry-run   只说做什么，不写文件
#   bash install-agentrouter-proxy.sh --uninstall 停用并删除单元与运行时副本（源码保留）
#
# 依赖 node/systemctl/ss/curl。unit_body() 是单元内容的唯一源：手改单元会被覆盖
# （覆盖前备份 .bak-<时间戳>）。DSH 侧供应商在 cordis.patch.yml，不在本脚本。

set -euo pipefail

BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
if [[ ! -t 1 ]]; then BOLD=""; RED=""; GREEN=""; YELLOW=""; NC=""; fi

SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SRC_DIR="$(cd -- "$(dirname -- "$SELF")" && pwd -P)"
SRC="$SRC_DIR/agentrouter-proxy.mjs"
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/agentrouter-proxy.mjs"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/agentrouter-proxy.service"
SERVICE="agentrouter-proxy.service"
PORT="${AGENTROUTER_PROXY_PORT:-8320}"

usage() {
  sed -n '2,14p' "$SELF" | sed 's/^# \{0,1\}//'
}

require_deps() {
  local missing=() cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if (( ${#missing[@]} > 0 )); then
    printf '%s错误: 缺少依赖:%s %s\n' "$RED" "$NC" "${missing[*]}" >&2
    exit 127
  fi
}

# 代码指纹：丢掉 shebang 与文件头 /** … */ 注释块 —— 注释措辞不同不算漂移，逻辑改动一律算
code_fp() {
  [[ -f "$1" ]] || { printf '%s' '-'; return; }
  awk 'NR==1 && /^#!/ {next}
       NR<=200 && !done { if ($0 ~ /^\/\*/) {inblk=1; next}
                          if (inblk) { if ($0 ~ /\*\//) {inblk=0; done=1} ; next }
                          done=1 }
       {print}' "$1" | md5sum | cut -d' ' -f1
}

# 单元指纹：只看生效指令（丢注释与空行）。参数为 - 时读 stdin
# （传 /dev/stdin 不行：管道上 [[ -f ]] 为假，会让上游 cat 拿到 EPIPE）
unit_fp() {
  if [[ "$1" == "-" ]]; then
    grep -vE '^[[:space:]]*(#|$)' - | md5sum | cut -d' ' -f1
  elif [[ -f "$1" ]]; then
    grep -vE '^[[:space:]]*(#|$)' "$1" | md5sum | cut -d' ' -f1
  else
    printf '%s' '-'
  fi
}

# ---------- 期望的单元内容（唯一源；--check 与安装共用） ----------
unit_body() {
  cat <<'UNIT_EOF'
[Unit]
Description=AgentRouter reverse proxy for DSH (codex wire image; egress via Clash)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/node %h/.local/bin/agentrouter-proxy.mjs
Environment=NODE_USE_ENV_PROXY=1
Environment=HTTPS_PROXY=http://127.0.0.1:7890
Environment=HTTP_PROXY=http://127.0.0.1:7890
Environment=NO_PROXY=127.0.0.1,localhost
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT_EOF
}

is_active() { systemctl --user is-active --quiet "$SERVICE"; }

port_listening() {
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${PORT}$"
}

probe_proxy() {
  # 只证明"经代理能打通上游"：401/403 也算链路通（缺 key 或无权限），000 = 没通
  curl -sS -m 8 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || printf '000'
}

report_line() {
  printf '  %-28s %s\n' "$1" "$2"
}

# ---------- --check：只读体检 ----------
do_check() {
  local drift=0 code unit_live svc port
  printf '%s== AgentRouter 反代体检（只读）==%s\n' "$BOLD" "$NC"

  if [[ ! -f "$SRC" ]]; then
    printf '%s错误: 源脚本缺失:%s %s\n' "$RED" "$NC" "$SRC" >&2
    exit 1
  fi

  code="$(code_fp "$SRC")"
  if [[ "$(code_fp "$DEST")" == "$code" ]]; then
    report_line "运行时副本" "${GREEN}与源一致${NC}"
  else
    report_line "运行时副本" "${RED}与源不一致（跑一次无参安装修复）${NC}"; drift=1
  fi

  unit_live="$(unit_body | unit_fp -)"
  if [[ "$(unit_fp "$UNIT")" == "$unit_live" ]]; then
    report_line "systemd 单元" "${GREEN}与脚本口径一致${NC}"
  else
    report_line "systemd 单元" "${YELLOW}与脚本口径不一致（被手工改过？无参安装会覆盖，先看 diff）${NC}"; drift=1
  fi

  if is_active; then svc="${GREEN}active${NC}"; else svc="${RED}inactive${NC}"; drift=1; fi
  report_line "$SERVICE" "$svc"

  if port_listening; then port="${GREEN}在听 :$PORT${NC}"; else port="${RED}未监听 :$PORT${NC}"; drift=1; fi
  report_line "本地端口" "$port"

  printf '%s' "  经代理探测 /v1/models"
  local http; http="$(probe_proxy)"
  case "$http" in
    000) printf '  %s→ 无响应（链路不通）%s\n' "$RED" "$NC"; drift=1 ;;
    2*)  printf '  %s→ HTTP %s（完全通）%s\n' "$GREEN" "$http" "$NC" ;;
    *)   printf '  %s→ HTTP %s（链路通，缺 key/无权限）%s\n' "$YELLOW" "$http" "$NC" ;;
  esac

  if (( drift )); then
    printf '%s体检结论: 有漂移或故障（退出码 1）%s\n' "$RED" "$NC"
    exit 1
  fi
  printf '%s体检结论: 全部一致（退出码 0）%s\n' "$GREEN" "$NC"
}

# ---------- 无参：安装 / 修复 ----------
do_install() {
  local backup
  require_deps node systemctl ss curl
  [[ -f "$SRC" ]] || { printf '%s错误: 同目录下没有 agentrouter-proxy.mjs%s\n' "$RED" "$NC" >&2; exit 1; }

  printf '%s== 安装 AgentRouter 反代 ==%s\n' "$BOLD" "$NC"
  mkdir -p "$DEST_DIR" "$UNIT_DIR"
  install -m 0600 "$SRC" "$DEST"
  printf '  已安装副本: %s\n' "$DEST"

  if [[ -f "$UNIT" ]]; then
    backup="$UNIT.bak-$(date +%Y%m%d-%H%M%S)"
    cp -a "$UNIT" "$backup"
    printf '  旧单元已备份: %s\n' "$backup"
  fi
  unit_body > "$UNIT"
  printf '  已写入单元: %s\n' "$UNIT"

  systemctl --user daemon-reload
  systemctl --user enable --now "$SERVICE" >/dev/null 2>&1 || true
  systemctl --user restart "$SERVICE"
  printf '  已 enable --now + restart\n'

  # 等端口起来（最多 10 秒）：刚 restart 时 bind 有毫秒级延迟
  local tries=0
  until port_listening || (( tries >= 10 )); do
    sleep 1
    (( tries++ )) || true
  done

  if ! is_active; then
    printf '%s错误: %s 未能启动，看日志：%s\n' "$RED" "$SERVICE" "$NC" >&2
    printf '  journalctl --user -u %s -n 40 --no-pager\n' "$SERVICE" >&2
    exit 1
  fi
  if ! port_listening; then
    printf '%s错误: 单元 active 但 :%s 未监听（端口被占或脚本报错）%s\n' "$RED" "$PORT" "$NC" >&2
    exit 1
  fi

  printf '  %s单元 active，:%s 在听%s\n' "$GREEN" "$PORT" "$NC"
  local http; http="$(probe_proxy)"
  case "$http" in
    000) printf '  %s经代理探测无响应 —— 检查 Clash（127.0.0.1:7890）是否在跑%s\n' "$RED" "$NC"; exit 1 ;;
    2*)  printf '  %s经代理 HTTP %s —— 完全通%s\n' "$GREEN" "$http" "$NC" ;;
    *)   printf '  %s经代理 HTTP %s —— 链路通（key 未配或无权限，属正常）%s\n' "$YELLOW" "$http" "$NC" ;;
  esac
  printf '%s安装完成。DSH 侧两条供应商（agentrouter-anth / agentrouter-resp）现在可用。%s\n' "$GREEN" "$NC"
}

# ---------- --uninstall ----------
do_uninstall() {
  printf '%s== 卸载 AgentRouter 反代 ==%s\n' "$BOLD" "$NC"
  systemctl --user disable --now "$SERVICE" >/dev/null 2>&1 || true
  printf '  已 stop + disable\n'
  [[ -f "$UNIT" ]] && rm -f "$UNIT" && printf '  已删除单元: %s\n' "$UNIT"
  [[ -f "$DEST" ]] && rm -f "$DEST" && printf '  已删除运行时副本: %s\n' "$DEST"
  systemctl --user daemon-reload
  printf '  源码仍保留在 %s（重装跑一次无参即可）\n' "$SRC"
}

# ---------- --dry-run ----------
do_dry_run() {
  printf '%s== dry-run（不写任何文件）==%s\n' "$BOLD" "$NC"
  printf '  将安装副本: %s → %s (0600)\n' "$SRC" "$DEST"
  printf '  将写入单元: %s（内容见 unit_body）\n' "$UNIT"
  printf '  将执行: systemctl --user daemon-reload && enable --now %s && restart\n' "$SERVICE"
  printf '  将验证: active + :%s 在听 + 经代理 /v1/models\n' "$PORT"
}

# --- 参数解析 ---
MODE="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --uninstall) MODE="uninstall"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '错误: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- 主逻辑 ---
case "$MODE" in
  check) do_check ;;
  dry-run) do_dry_run ;;
  uninstall) do_uninstall ;;
  install) do_install ;;
esac
