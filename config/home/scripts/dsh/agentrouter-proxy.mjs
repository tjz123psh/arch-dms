#!/usr/bin/env node
/**
 * AgentRouter（agentrouter.org）本地反向代理，监听 8320。
 *
 * 三件必需的改造：① 该站只经 Clash(7890) 可达，DSH 进程没设代理；② 只认 Codex 线形头
 * （originator/version/session_id/OpenAI-Beta/User-Agent），否则 invalid codex request；
 * ③ /v1/messages 补 anthropic-beta: context-1m-2025-08-07。
 * 纯透传、**不重试**（DSH 自己会重试）。出网靠单元的 NODE_USE_ENV_PROXY + HTTPS_PROXY。
 * DSH 侧 baseURL：http://127.0.0.1:8320/v1（responses）或 http://127.0.0.1:8320（anthropic）。
 */
import http from "node:http";
import { randomUUID } from "node:crypto";
import { Readable } from "node:stream";

const UPSTREAM = process.env.AGENTROUTER_PROXY_UPSTREAM ?? "https://agentrouter.org";
const PORT = Number(process.env.AGENTROUTER_PROXY_PORT ?? 8320);
const BIND = process.env.AGENTROUTER_PROXY_BIND ?? "127.0.0.1";

const CODEX_HEADERS = {
  originator: "codex_cli_rs",
  version: "0.153.0",
  "user-agent": "codex_cli_rs/0.153.0 (Linux; x86_64)",
  "openai-beta": "responses=experimental",
};
const REPLACED = new Set(["host", "originator", "version", "user-agent", "session_id", "openai-beta"]);

const log = (...a) => console.log(new Date().toTimeString().slice(0, 8), ...a);

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
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

  const controller = new AbortController();
  res.on("close", () => { if (!res.writableEnded) controller.abort(); });
  const timeout = setTimeout(() => controller.abort(), 10 * 60 * 1000);
  timeout.unref();

  try {
    const upstream = await fetch(url, { method: req.method, headers, body: hasBody ? body : undefined, signal: controller.signal });
    clearTimeout(timeout);
    res.writeHead(upstream.status, Object.fromEntries(upstream.headers));
    const stream = Readable.fromWeb(upstream.body);
    stream.on("error", (error) => { log(req.method, req.url, "-> stream error:", error?.message ?? error); res.destroy(); });
    stream.pipe(res);
  } catch (error) {
    clearTimeout(timeout);
    const reason = error?.cause?.code ?? error?.message ?? String(error);
    log(req.method, req.url, "-> upstream failed:", reason);
    if (!res.headersSent) {
      res.writeHead(502, { "content-type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ error: { message: "agentrouter-proxy: " + reason, type: "proxy_error" } }));
    } else res.destroy();
  }
});

server.listen(PORT, BIND, () => {
  log("[agentrouter-proxy] http://" + BIND + ":" + PORT + " -> " + UPSTREAM + " | codex 头注入 | 纯透传（不重试）");
});
