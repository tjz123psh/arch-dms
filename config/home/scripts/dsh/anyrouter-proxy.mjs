#!/usr/bin/env node
/**
 * anyrouter-proxy — AnyRouter（anyrouter.top）本地反向代理。
 *
 * 它解决三件事：
 *
 * 1) 网络：anyrouter.top 只经 Clash（127.0.0.1:7890）可达；直连 TLS 握手失败。
 *
 * 2) Codex 线形：AnyRouter 的 gpt-6-astra 走 /v1/responses，且**只接受 Codex CLI 形状的
 *    请求**——缺 session_id / OpenAI-Beta / originator / version 会回
 *    400 invalid codex request。DSH/pi-ai 无法自带这些头，所以在这一层注入
 *    （session_id 优先取请求体里的 prompt_cache_key，保证同会话同 session_id）。
 *    /v1/messages（claude 系）另需 anthropic-beta: context-1m-2025-08-07，这里兜底注入。
 *
 * 3) 挤信道：gpt-6-astra 是共享池，信道常满。失败（5xx / 429 / WAF 拦截页 / 网络错）
 *    都在转发层自动重试，对 DSH 完全透明。两个可调开关：
 *      · HEDGE（对冲并发）：一轮同时发 N 个请求，谁先成功用谁 —— 把"每 80 秒 1 次机会"
 *        变成"每 80 秒 N 次机会"。实测网关在信道满时会把请求挂 ~80 秒才回 500，
 *        所以并发是提高命中率的关键手段。
 *      · FIRST_BYTE_MS（首字节超时）：超过 N 毫秒还没等到响应头就取消、立刻重发
 *        （即"看到卡住就取消重来"的自动化版）。0 = 关闭（让排队的请求有机会被服务）。
 *
 * 环境变量（都有默认值）：
 *   ANYROUTER_PROXY_PORT=8321
 *   ANYROUTER_PROXY_RETRY_ATTEMPTS=400        总尝试次数上限
 *   ANYROUTER_PROXY_RETRY_BUDGET_MS=240000    总时间预算（压在 DSH 5 分钟空闲超时内）
 *   ANYROUTER_PROXY_HEDGE=1                   一轮并发数
 *   ANYROUTER_PROXY_FIRST_BYTE_MS=0           首字节超时（0=关）
 *   ANYROUTER_PROXY_RETRY_MIN_MS=120          「信道满」重试间隔下限
 *   ANYROUTER_PROXY_RETRY_MAX_MS=600          「信道满」重试间隔上限
 *   ANYROUTER_PROXY_RETRY_SLOW_MIN_MS=2000    「风控」退避起点（429 / WAF）
 *   ANYROUTER_PROXY_RETRY_SLOW_MAX_MS=10000   「风控」退避上限
 *
 * 修复记录：
 *   2026-10-04 对冲赢家的响应体被自己 abort（`ctls.forEach(c => c.abort()` 误伤赢家）⇒ 带真 key 的
 *   较大成功响应客户端收到空回复（实测 /v1/models → curl (52) Empty reply）。改为只掐输家。
 *
 * Egress 走 Clash：由 systemd 单元设 NODE_USE_ENV_PROXY=1 + HTTPS_PROXY。
 * 路径原样透传，故 DSH 侧 baseURL 配 http://127.0.0.1:8321/v1。
 */
import http from "node:http";
import { randomUUID } from "node:crypto";
import { once } from "node:events";

const UPSTREAM = process.env.ANYROUTER_PROXY_UPSTREAM ?? "https://anyrouter.top";
const PORT = Number(process.env.ANYROUTER_PROXY_PORT ?? 8321);
const BIND = process.env.ANYROUTER_PROXY_BIND ?? "127.0.0.1";
const ATTEMPTS = Number(process.env.ANYROUTER_PROXY_RETRY_ATTEMPTS ?? 400);
const RETRY_BUDGET = Number(process.env.ANYROUTER_PROXY_RETRY_BUDGET_MS ?? 240000);
const HEDGE = Math.max(1, Number(process.env.ANYROUTER_PROXY_HEDGE ?? 1));
const FIRST_BYTE_MS = Number(process.env.ANYROUTER_PROXY_FIRST_BYTE_MS ?? 0);
const FAST_MIN = Number(process.env.ANYROUTER_PROXY_RETRY_MIN_MS ?? 120);
const FAST_MAX = Number(process.env.ANYROUTER_PROXY_RETRY_MAX_MS ?? 600);
const SLOW_MIN = Number(process.env.ANYROUTER_PROXY_RETRY_SLOW_MIN_MS ?? 2000);
const SLOW_MAX = Number(process.env.ANYROUTER_PROXY_RETRY_SLOW_MAX_MS ?? 10000);

// Codex CLI wire image —— AnyRouter 的 codex 信道靠它识别客户端。
// 站点公告（2026-09-05）："本站已支持 gpt-6-astra 1M 上下文窗口，由于 codex 默认配置
// 原因，请更新到 codex v0.153.0 以上版本使用" —— 所以这里报 0.153.0，别用旧版本号。
const CODEX_HEADERS = {
  originator: "codex_cli_rs",
  version: "0.153.0",
  "user-agent": "codex_cli_rs/0.153.0 (Linux; x86_64)",
  "openai-beta": "responses=experimental",
};
const REPLACED = new Set(["host", "originator", "version", "user-agent", "session_id", "openai-beta"]);

const RETRYABLE_TEXT = /负载|上限|get_channel_failed|too many requests|overloaded|temporar|service unavailable|请稍后重试/i;
// 明确**不重试**的错误：这类必须等窗口过去，立刻重试只会更烧配额（2026-10-04 实测教训）
const NON_RETRYABLE_TEXT = /token rate limit|exceeded token|quota has been exhausted|budget pool|insufficient/i;
const log = (...a) => console.log(new Date().toTimeString().slice(0, 8), ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function isBlockPage(text) {
  const head = String(text).trimStart().slice(0, 300).toLowerCase();
  return head.startsWith("<") || head.includes("aliyun_waf") || head.includes("<!doctype");
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

/**
 * 单次尝试。返回：
 *   { kind: "ok", status, reader, first, upstream }      成功（已窥探首块，可开始转发）
 *   { kind: "retry", status, text, throttled }           可重试失败
 *   { kind: "fatal", status, text }                      不该重试（400/401 等）
 */
async function tryOnce({ url, method, headers, body, firstByteMs, ctl }) {
  let timer = null;
  if (firstByteMs > 0) {
    timer = setTimeout(() => ctl.abort(new Error("first-byte-timeout")), firstByteMs);
  }
  try {
    const upstream = await fetch(url, { method, headers, body, signal: ctl.signal });
    if (timer) { clearTimeout(timer); timer = null; }

    if (upstream.status >= 400) {
      const text = await upstream.text();
      const throttled = upstream.status === 429 || isBlockPage(text);
      // 先排除"不重试"类（TPM 限流 / 额度耗尽）：这类重试只会更烧配额
      const retryable = !NON_RETRYABLE_TEXT.test(text) &&
        (upstream.status >= 500 || upstream.status === 429 || RETRYABLE_TEXT.test(text) || isBlockPage(text));
      return { kind: retryable ? "retry" : "fatal", status: upstream.status, text, throttled };
    }

    const reader = upstream.body.getReader();
    const first = await reader.read();
    const head = first.value ? Buffer.from(first.value).toString("utf8", 0, 300) : "";
    if (isBlockPage(head)) {
      try { await reader.cancel(); } catch {}
      return { kind: "retry", status: upstream.status, text: "WAF 拦截页(HTML)", throttled: true };
    }
    return { kind: "ok", status: upstream.status, upstream, reader, first, ctl };
  } catch (error) {
    const reason = error?.cause?.code ?? error?.message ?? String(error);
    const timedOut = ctl.signal.aborted && String(ctl.signal.reason?.message ?? ctl.signal.reason) === "first-byte-timeout";
    return {
      kind: "retry",
      status: 0,
      text: timedOut ? "首字节超时(" + firstByteMs + "ms)" : "网络失败(" + reason + ")",
      throttled: false,
    };
  } finally {
    if (timer) clearTimeout(timer);
  }
}

const server = http.createServer(async (req, res) => {
  const url = UPSTREAM + req.url;
  const hasBody = req.method !== "GET" && req.method !== "HEAD";

  let body;
  let sessionId;
  if (hasBody) {
    body = await readBody(req);
    try {
      const parsed = JSON.parse(body.toString("utf8"));
      if (typeof parsed?.prompt_cache_key === "string" && parsed.prompt_cache_key) sessionId = parsed.prompt_cache_key;
    } catch {}
  }

  const headers = { ...CODEX_HEADERS, session_id: sessionId ?? randomUUID() };
  for (const [name, value] of Object.entries(req.headers)) {
    if (REPLACED.has(name)) continue;
    headers[name] = value;
  }
  if (req.url.startsWith("/v1/messages")) {
    headers["anthropic-beta"] = headers["anthropic-beta"]
      ? headers["anthropic-beta"] + ",context-1m-2025-08-07"
      : "context-1m-2025-08-07";
  }

  const clientGone = new AbortController();
  res.on("close", () => { if (!res.writableEnded) clientGone.abort(); });

  const started = Date.now();
  let fastDelay = FAST_MIN;
  let slowDelay = SLOW_MIN;
  let attempts = 0;
  let last = null;

  while (attempts < ATTEMPTS && Date.now() - started < RETRY_BUDGET) {
    if (clientGone.signal.aborted) { res.destroy(); return; }

    const n = Math.min(HEDGE, ATTEMPTS - attempts);
    attempts += n;
    const ctls = Array.from({ length: n }, () => new AbortController());
    const pending = ctls.map((ctl) =>
      tryOnce({ url, method: req.method, headers, body: hasBody ? body : undefined, firstByteMs: FIRST_BYTE_MS, ctl })
        .catch((error) => ({ kind: "retry", status: 0, text: "内部错误(" + (error?.message ?? error) + ")", throttled: false })),
    );

    // 对冲的关键：谁先成功用谁，立刻掐掉其余 —— 不等奖池里最慢的那个
    let winner = null;
    const results = await new Promise((resolve) => {
      let left = n;
      const done = [];
      pending.forEach((p, i) =>
        p.then((r) => {
          done[i] = r;
          if (!winner && r.kind === "ok") { winner = r; resolve(done.filter(Boolean)); return; }
          if (--left === 0) resolve(done.filter(Boolean));
        }),
      );
    });
    // 2026-10-04 修：只掐**输家**。原写法 `ctls.forEach((c) => c.abort())` 把赢家自己的
    // 控制器也 abort 了，而赢家的响应体流还挂在那个 signal 上 ⇒ 已读完首块但还没读完正文的
    // 响应（实测 /v1/models 的 7.4KB 200）会在 read() 处抛 "This operation was aborted"，
    // 客户端拿到 `curl: (52) Empty reply from server`。小响应（401 之类）因为首块即全部，
    // 恰好躲过 ⇒ 这个 bug 只在"带真 key 的成功响应"上现形。
    if (winner) ctls.forEach((c) => { if (c !== winner.ctl) c.abort(); });

    if (winner) {
      if (attempts > n || n > 1) log("第 " + attempts + " 次（并发 " + n + "）：✅ 挤进信道，开始转发 " + req.url);
      res.writeHead(winner.status, Object.fromEntries(winner.upstream.headers));
      try {
        if (winner.first.value && !res.write(Buffer.from(winner.first.value))) await once(res, "drain");
        if (winner.first.done) { res.end(); return; }
        for (;;) {
          const { done, value } = await winner.reader.read();
          if (done) break;
          if (value && !res.write(Buffer.from(value))) await once(res, "drain");
        }
        res.end();
      } catch (error) {
        log("转发中断:", error?.message ?? error);
        res.destroy();
      }
      return;
    }

    const fatal = results.find((r) => r.kind === "fatal");
    if (fatal) {
      res.writeHead(fatal.status, { "content-type": "application/json; charset=utf-8" });
      res.end(String(fatal.text));
      return;
    }

    last = results[0];
    const throttled = results.some((r) => r.throttled);
    const base = throttled ? slowDelay : fastDelay;
    const wait = Math.round(base * (0.8 + Math.random() * 0.4));
    const elapsed = ((Date.now() - started) / 1000).toFixed(0);
    log("第 " + attempts + " 次（并发 " + n + "，" + elapsed + "s）：" + req.url +
        (throttled ? " 风控/限流" : " 信道满") + "（HTTP " + last.status + "，" +
        String(last.text).replace(/\s+/g, " ").slice(0, 60) + "），" + wait + "ms 后重试");

    if (Date.now() - started + wait >= RETRY_BUDGET) break;
    await sleep(wait);
    if (throttled) slowDelay = Math.min(SLOW_MAX, Math.round(slowDelay * 1.7));
    else fastDelay = Math.min(FAST_MAX, Math.round(fastDelay * 1.3));
  }

  if (!res.headersSent) {
    const secs = Math.round((Date.now() - started) / 1000);
    if (last && last.status >= 400) {
      res.writeHead(last.status, { "content-type": "application/json; charset=utf-8" });
      res.end(String(last.text));
    } else {
      res.writeHead(503, { "content-type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({
        error: {
          message: "anyrouter-proxy: 信道一直满（" + attempts + " 次尝试 / " + secs + "s）" + (last ? " 最后一次：" + String(last.text).slice(0, 120) : ""),
          type: "proxy_error",
        },
      }));
    }
  }
});

server.listen(PORT, BIND, () => {
  log("[anyrouter-proxy] http://" + BIND + ":" + PORT + " -> " + UPSTREAM +
      " | codex 头注入 | 对冲并发 " + HEDGE + " | 首字节超时 " + (FIRST_BYTE_MS > 0 ? FIRST_BYTE_MS + "ms" : "关") +
      " | 信道满重试 " + FAST_MIN + "-" + FAST_MAX + "ms | 风控退避 " + SLOW_MIN + "-" + SLOW_MAX + "ms" +
      " | 最多 " + ATTEMPTS + " 次 / 预算 " + RETRY_BUDGET + "ms");
});
