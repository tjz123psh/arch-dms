#!/usr/bin/env bash
# astra-watcher.sh —— 盯「AnyRouter 的 gpt-6-astra 什么时候能用」。
#
# 为什么需要它：2026-10-04 那次教训 —— 盲目重试时 Clash 节点其实已经挂了，
# 上万次"尝试"全打在断掉的网络路径上（ECONNRESET），完全无效。
# 所以本脚本每轮**先确认 Clash 节点活着**，活着才去探 astra。
#
# 用法：
#   bash ~/scripts/dsh/astra-watcher.sh              # 默认盯 4 小时，每 60 秒一轮
#   CYCLES=10 INTERVAL=30 bash ~/scripts/dsh/astra-watcher.sh
#
# 退出码：0 = astra 通了（会把返回内容打出来）；1 = 盯完都没通。
# 日志：直接打 stdout（放后台时用 journalctl 或重定向到文件看）。

set -uo pipefail
export HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890

CYCLES="${CYCLES:-240}"
INTERVAL="${INTERVAL:-60}"
CRED="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
KEY="$(sed -n 's/^ *ANYROUTER_API_KEY: //p' "$CRED" 2>/dev/null | head -1)"
[ -n "$KEY" ] || { echo "❌ 读不到 ANYROUTER_API_KEY（$CRED）"; exit 2; }

# 注意：AnyRouter 只认**完整 codex 形状**——缺 tools / tool_choice / parallel_tool_calls
# 会直接回 400 invalid codex request（实测 2026-10-04）。别精简这个 body。
# codex 版本号与 anyrouter-proxy.mjs 的 CODEX_HEADERS 对齐（站点要求 ≥0.153.0）——
# 改一处记得改另一处（同一台机上的两条链路报同一个客户端）。
BODY='{"model":"gpt-6-astra","input":[{"type":"message","role":"user","content":[{"type":"input_text","text":"say ok"}]}],"tools":[],"tool_choice":"auto","parallel_tool_calls":false,"reasoning":{"effort":"low","summary":"auto"},"include":["reasoning.encrypted_content"],"prompt_cache_key":"watcher","store":false,"stream":true,"max_output_tokens":60}'

stamp() { date +%H:%M:%S; }

node_alive() {
  # 走 Clash 打一个轻量外网站点：通 = 节点活着
  curl -sS -m 10 -o /dev/null -w "%{http_code}" https://www.gstatic.com/generate_204 2>/dev/null | grep -qE "204|200"
}

for i in $(seq 1 "$CYCLES"); do
  if ! node_alive; then
    echo "[$(stamp)] 第 $i 轮：⚠️  Clash 节点不通（所有走代理的请求都会失败）—— 跳过探测，等你换节点/重连"
    sleep "$INTERVAL"; continue
  fi

  # 超时必须 > 网关的 82 秒拒绝窗口，否则只会看到"超时"、拿不到确定答案
  OUT="$(curl -sS -N -m 100 -X POST https://anyrouter.top/v1/responses \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -H "originator: codex_cli_rs" -H "version: 0.153.0" \
    -H "session_id: watcher-$(date +%s)" -H "OpenAI-Beta: responses=experimental" \
    -H "User-Agent: codex_cli_rs/0.153.0 (Linux; x86_64)" -d "$BODY" 2>&1)"

  if printf '%s' "$OUT" | grep -q "response.created"; then
    echo "[$(stamp)] ✅✅ ASTRA_OPEN —— 第 $i 轮探测通了！"
    printf '%s' "$OUT" | grep -oE '"text":"[^"]{0,160}' | head -2
    exit 0
  fi

  case "$OUT" in
    *负载*|*上限*) echo "[$(stamp)] 第 $i 轮：节点通，但 astra 信道满（负载达到上限）" ;;
    *invalid\ codex*) echo "[$(stamp)] 第 $i 轮：节点通，但请求形状被拒（invalid codex request）" ;;
    *SSL*|*TLS*) echo "[$(stamp)] 第 $i 轮：节点通但 AnyRouter 这条 TLS 失败（可能换节点更稳）" ;;
    *) echo "[$(stamp)] 第 $i 轮：$(printf '%s' "$OUT" | tr -d '\n' | head -c 90)" ;;
  esac
  sleep "$INTERVAL"
done

echo "[$(stamp)] 盯守结束（$CYCLES 轮都没通）"
exit 1
