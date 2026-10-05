#!/usr/bin/env bash
# install-anyrouter-proxy.sh —— 一键把 AnyRouter 本地转发装成 systemd 用户服务（常驻）。
#
# 干什么：
#   1. 把同目录的 anyrouter-proxy.mjs 装到 ~/.local/bin/
#   2. 写 ~/.config/systemd/user/anyrouter-proxy.service（含 Codex 头注入 + 挤信道重试参数）
#   3. daemon-reload → enable --now → restart
#   4. 验证：服务状态 + 通过转发打一次 /v1/models
#
# 用法（重装 DSH 后、或换机后；无参数 = 安装/修复）：
#   bash ~/scripts/dsh/install-anyrouter-proxy.sh             # 安装或按本脚本口径修复
#   bash ~/scripts/dsh/install-anyrouter-proxy.sh --check     # 只体检，不写任何文件
#
# 依赖：
#   · node（/usr/bin/node）
#   · Clash 在 127.0.0.1:7890（转发靠它出网）
#   · ~/.dsh/.credentials.yaml 里有 ANYROUTER_API_KEY（仅用于第 5 步连通性验证）
#
# 调参口径（2026-10-04 定，**与线上运行的单元一致**）：
#   下面 unit_body 里的 Environment 就是"当前有效值"。改参数请**同时**改这里和
#   ~/.config/systemd/user/anyrouter-proxy.service，再跑一次本脚本；
#   只改单元不跑脚本 → 下次重装会被本脚本覆盖回去（--check 会先报出来）。
#   · HEDGE=1           一轮并发 1（>1 = 同时发多个请求赌谁先成功，费额度）
#   · FIRST_BYTE_MS=0   首字节超时关闭（非 0 = 卡住就取消重发）
#   · ATTEMPTS=5 / RETRY_*_MS=2000-10000   温和退避；预算 90s，压在 DSH 5 分钟空闲超时内
#
# 注意：DSH 侧的 provider 配置（anyrouter 等路由）不在本脚本里——它在
#   ~/.dsh/profiles/<profile>/cordis.patch.yml。权威片段见本脚本末尾的 NOTE 段；
#   配套说明在 ~/md/供应商配置/dsh-供应商链路恢复文档.md。

set -uo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SRC_DIR/anyrouter-proxy.mjs"
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/anyrouter-proxy.mjs"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/anyrouter-proxy.service"
CRED="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
SERVICE="anyrouter-proxy.service"
PORT=8321
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '2,28p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "未知参数: $1（可用 --check / -h）" >&2; exit 2 ;;
  esac
done

md5_of() { [ -f "$1" ] && md5sum "$1" | cut -d" " -f1 || echo "-"; }

# 代码指纹：丢掉 shebang 与文件头的 /** … */ 注释块再比 —— **注释措辞 / 出处标注不同不算漂移**，
# 但逻辑改动一律算（这正是"改了源却忘了重装副本"要抓的东西）。
code_fp() {
  [ -f "$1" ] || { echo "-"; return; }
  awk 'NR==1 && /^#!/ {next}
       NR<=200 && !done { if ($0 ~ /^\/\*/) {inblk=1; next} ; if (inblk) { if ($0 ~ /\*\//) {inblk=0; done=1} ; next } ; done=1 }
       {print}' "$1" | md5sum | cut -d" " -f1
}

# 单元指纹：只看**生效指令**（丢掉注释/空行），所以注释措辞不同不算漂移。
unit_fp() { [ -f "$1" ] && grep -vE '^[[:space:]]*(#|$)' "$1" | md5sum | cut -d" " -f1 || echo "-"; }

# ---------- 期望的单元内容（唯一副本；--check 与安装都用它） ----------
unit_body() {
  cat <<'UNIT_EOF'
[Unit]
Description=AnyRouter reverse proxy for DSH (codex wire image + channel-full retry; egress via Clash)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/node %h/.local/bin/anyrouter-proxy.mjs
Environment=NODE_USE_ENV_PROXY=1
Environment=HTTPS_PROXY=http://127.0.0.1:7890
Environment=HTTP_PROXY=http://127.0.0.1:7890
Environment=NO_PROXY=127.0.0.1,localhost
# 挤信道重试（客户端 DSH 空闲超时 5 分钟，这里预算留 90 秒）
Environment=ANYROUTER_PROXY_HEDGE=1
Environment=ANYROUTER_PROXY_FIRST_BYTE_MS=0
Environment=ANYROUTER_PROXY_RETRY_ATTEMPTS=5
Environment=ANYROUTER_PROXY_RETRY_MIN_MS=2000
Environment=ANYROUTER_PROXY_RETRY_MAX_MS=10000
Environment=ANYROUTER_PROXY_RETRY_BUDGET_MS=90000
Environment=ANYROUTER_PROXY_RETRY_SLOW_MIN_MS=2000
Environment=ANYROUTER_PROXY_RETRY_SLOW_MAX_MS=10000
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT_EOF
}

SRC_MD5="$(md5_of "$SRC")"
DEST_MD5="$(md5_of "$DEST")"
SRC_CODE="$(code_fp "$SRC")"
DEST_CODE="$(code_fp "$DEST")"
UNIT_FP="$(unit_fp "$UNIT")"
WANT_FP="$(unit_body | grep -vE '^[[:space:]]*(#|$)' | md5sum | cut -d" " -f1)"
UNIT_DRIFT=1
[ "$(unit_fp "$UNIT")" = "$WANT_FP" ] && UNIT_DRIFT=0

# ---------- --check：只读体检（不写任何文件，退出码见末尾注释） ----------
if [ "$CHECK" = 1 ]; then
  rc=0
  echo "== 体检（不写任何文件）=="
  if [ ! -f "$SRC" ]; then echo "  ❌ 源脚本不存在: $SRC"; rc=3
  elif [ "$DEST_MD5" = "-" ]; then echo "  ⚠️  还没装到 $DEST（跑一次无参安装）"; rc=1
  elif [ "$SRC_CODE" = "$DEST_CODE" ]; then
    [ "$SRC_MD5" = "$DEST_MD5" ] && echo "  ✅ 已装副本与源脚本逐字节一致（$SRC_MD5）" \
                                 || echo "  ✅ 已装副本与源脚本**代码等价**（仅头注释不同，正常）"
  else echo "  ❌ 已装副本的代码与源脚本不一致（源代码 $SRC_CODE / 装 $DEST_CODE）—— 跑一次无参安装同步"; rc=1
  fi
  if [ "$UNIT_FP" = "-" ]; then echo "  ⚠️  单元不存在: $UNIT（跑一次无参安装）"; rc=1
  elif [ "$UNIT_DRIFT" = 0 ]; then echo "  ✅ 单元与本脚本口径一致"
  else
    echo "  ⚠️  单元生效指令与本脚本口径不同（单元 $UNIT_FP / 期望 $WANT_FP）"
    echo "        ▶ 线上是调过的参数，这算正常；要保留就别跑无参安装。"
    echo "          想以线上为准：把 $UNIT 的 Environment 段抄回本脚本的 unit_body。"
    rc=2
  fi
  st="$(systemctl --user is-active "$SERVICE" 2>/dev/null)"
  en="$(systemctl --user is-enabled "$SERVICE" 2>/dev/null)"
  echo "  服务: $st / $en"
  [ "$st" = "active" ] || rc=1
  if ss -ltn 2>/dev/null | grep -q ":$PORT "; then echo "  ✅ 127.0.0.1:$PORT 在监听"; else echo "  ❌ 127.0.0.1:$PORT 没在监听"; rc=1; fi
  echo "  （退出码：0=全一致 / 1=有故障 / 2=单元与脚本口径不同 / 3=源脚本缺失）"
  exit "$rc"
fi

# ---------- 安装 ----------
echo "== 1/5 前置检查 =="
[ -f "$SRC" ] || { echo "❌ 找不到源脚本: $SRC"; exit 1; }
command -v node >/dev/null || { echo "❌ 找不到 node"; exit 1; }
echo "  node: $(command -v node)"
if ss -ltn 2>/dev/null | grep -q ":7890 "; then
  echo "  Clash 127.0.0.1:7890: 在跑 ✅"
else
  echo "  ⚠️  Clash 127.0.0.1:7890 没在跑 —— 转发会连不上 AnyRouter（先起 Clash）"
fi

echo "== 2/5 安装脚本 → $DEST =="
mkdir -p "$DEST_DIR"
if [ "$SRC_MD5" = "$DEST_MD5" ]; then
  echo "  已是最新（$SRC_MD5），跳过"
else
  install -m 700 "$SRC" "$DEST"
  echo "  已安装（700）：源 $SRC_MD5 / 装前 $DEST_MD5 → 装后 $(md5_of "$DEST")"
fi

echo "== 3/5 写 systemd 单元 → $UNIT =="
mkdir -p "$UNIT_DIR"
if [ "$UNIT_DRIFT" = 0 ]; then
  echo "  已与本脚本口径一致，跳过"
else
  if [ -f "$UNIT" ]; then
    BAK="$UNIT.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$UNIT" "$BAK"
    echo "  ⚠️  原单元与本脚本口径不同，已备份为 $BAK"
    echo "      （若那份是手工调过的好配置，用 --check 的输出把它抄回本脚本的 unit_body）"
  fi
  unit_body > "$UNIT"
  echo "  已写入"
fi

echo "== 4/5 启用并启动 =="
systemctl --user daemon-reload
systemctl --user enable "$SERVICE" >/dev/null 2>&1 || true
systemctl --user restart "$SERVICE"
sleep 2
echo "  状态: $(systemctl --user is-active "$SERVICE") / $(systemctl --user is-enabled "$SERVICE")"

echo "== 5/5 连通性验证（经转发打 /v1/models）=="
KEY="$(sed -n 's/^ *ANYROUTER_API_KEY: //p' "$CRED" 2>/dev/null | head -1)"
if [ -z "$KEY" ]; then
  echo "  ⚠️  没读到 ANYROUTER_API_KEY（$CRED），跳过验证"
else
  CODE="$(curl -sS -m 30 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/v1/models" -H "Authorization: Bearer $KEY" || true)"
  echo "  GET http://127.0.0.1:$PORT/v1/models → HTTP $CODE"
  case "$CODE" in
    200) echo "  ✅ 转发已打通（带 key 200）" ;;
    401) echo "  ✅ 链路通（上游回 401 = 请求到了上游，只是 key 没被认，查 $CRED）" ;;
    *)   echo "  ❌ 没通（看 journalctl --user -u $SERVICE）" ;;
  esac
fi

cat <<'NOTE_EOF'

────────────────────────────────────────────────────────────
DSH 侧还需要 provider 路由（在 ~/.dsh/profiles/<profile>/cordis.patch.yml
的 llm-pi-ai.providers 里）。重装/还原 DSH 后把这段交给 agent 加上：

      anyrouter:
        displayName: AnyRouter（anyrouter.top）
        apiKeyEnv: ANYROUTER_API_KEY
        api: openai-responses
        baseURL: http://127.0.0.1:8321/v1
        models:
          - id: gpt-6-astra
            name: GPT-6 Astra
            contextWindow: 1050000
            maxTokens: 128000
            input: [text, image]
            reasoningEfforts: {low: low, medium: medium, high: high, xhigh: xhigh, max: max}

注：旧版这里还带一段 anyrouter-anth（Anthropic 协议、Claude Fable 5.1 /
GPT-6 Astra CC 格式）。2026-10-04 按用户要求"同一供应商放到一起"已从 profile
删除（同一 llm-pi-ai 分组只能有一种协议，装不进 astra 那个分组）。
需要时照 profile 里那段注释加回。

（凭据 ~/.dsh/.credentials.yaml 里要有 ANYROUTER_API_KEY）
────────────────────────────────────────────────────────────
NOTE_EOF
