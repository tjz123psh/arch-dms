#!/usr/bin/env bash
# rebuild-plugin-devhost-tree.sh —— 重建本地自研插件的**开发测试树**（DSH 本体每次升级后跑一次）。
#
# 为什么需要它（2026-10-10 实测踩到）：自研插件的 node_modules 是**手工拼的**（不是 pnpm install 出来的），
# 里面的宿主副本（@deepseek-ai/*）会随 DSH 本体升级而过期；症状是插件自检大面积 ERR_MODULE_NOT_FOUND
# ——当时 dsh-web-fetch-global 的 8 个单测有 6 个、外加 3 个脚本直接跑不起来（宿主层还停在 0.1.5-rc.1 时代），
# 而 npm run dsh:verify 只报 canary 漂移，看不出「套件其实已经哑了」。
#
# 做法（两个来源，都不是猜的）：
#   ① 宿主层 @deepseek-ai/* 从**正在运行的 app.asar** 物化 —— 就是运行时那一份，天然与当前版本对齐；
#   ② 插件自身依赖闭包从 profile 装机树补齐（linkedom→htmlparser2 这类）；
#   ③ 跑 npm run test:unit 验收。
#
# 用法：
#   bash ~/scripts/dsh/rebuild-plugin-devhost-tree.sh [插件目录]              # 重建 + 验收
#   bash ~/scripts/dsh/rebuild-plugin-devhost-tree.sh --check [插件目录]      # 只读体检：0=树是新的 1=该重建了
# 环境变量覆盖：DSH_DESKTOP_ASAR（asar 路径）、DSH_PROFILE_DIR（profile 的 node_modules）
set -o pipefail

if [ "$1" = "--check" ]; then MODE=--check; shift; else MODE=apply; fi
PLUGIN="$1"
[ -n "$PLUGIN" ] || PLUGIN=/home/pang/Projects/dsh/dsh-web-fetch-global
ASAR="$DSH_DESKTOP_ASAR"
[ -n "$ASAR" ] || ASAR=/usr/lib/deepseek-harness-desktop/resources/app.asar
PROFILE_NM="$DSH_PROFILE_DIR"
[ -n "$PROFILE_NM" ] || PROFILE_NM=/home/pang/.dsh/profiles/desktop/node_modules
BIN=/usr/lib/deepseek-harness-desktop/deepseek-harness

[ -f "$PLUGIN/package.json" ] || { echo "找不到插件: $PLUGIN" >&2; exit 2; }
[ -f "$ASAR" ] || { echo "找不到 app.asar: $ASAR" >&2; exit 2; }

# 内嵌 Node 程序：宿主层要读 asar 内文件，必须由 Electron 以 ELECTRON_RUN_AS_NODE 跑（普通 node 读不进 asar）。
JS="$(mktemp -t dsh-devtree-XXXXXX.cjs)"
trap 'rm -f "$JS"' EXIT
cat > "$JS" <<'JSEOF'
const fs = require('fs');
const [PLUGIN, ASAR, PROFILE_NM, MODE] = process.argv.slice(2);
const CHECK = MODE === '--check';
const ASAR_NM = ASAR + '/dsh/node_modules';
const LOCAL_NM = PLUGIN + '/node_modules';

const readJson = (p) => { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; } };
const pkgAt = (base, name) => readJson(base + '/' + name + '/package.json');
const pkgJson = readJson(PLUGIN + '/package.json');
if (!pkgJson) { console.error('宿主插件 package.json 读不到: ' + PLUGIN); process.exit(2); }

function closure(roots, resolve) {
  const seen = new Set(), queue = [...roots], unresolved = [];
  while (queue.length) {
    const n = queue.shift(); if (seen.has(n)) continue;
    const r = resolve(n); if (!r) { unresolved.push(n); continue; }
    seen.add(n);
    for (const f of ['dependencies', 'peerDependencies', 'optionalDependencies'])
      for (const d of Object.keys(r.meta[f] || {})) if (!seen.has(d)) queue.push(d);
  }
  return { seen: [...seen].sort(), unresolved };
}
function copyTree(src, dst) {
  const ents = (() => { try { return fs.readdirSync(src, { withFileTypes: true }); } catch { return []; } })();
  fs.mkdirSync(dst, { recursive: true });
  let bytes = 0, files = 0;
  for (const e of ents) {
    const s = src + '/' + e.name, d = dst + '/' + e.name;
    if (e.isDirectory()) { const r = copyTree(s, d); bytes += r.bytes; files += r.files; }
    else { let b; try { b = fs.readFileSync(s); } catch { continue; } fs.writeFileSync(d, b); bytes += b.length; files++; }
  }
  return { bytes, files };
}

/* ---------- ① 宿主层：@deepseek-ai/*，源 = 正在运行的 app.asar ---------- */
const peers = Object.keys(pkgJson.peerDependencies || {}).filter((k) => k.startsWith('@deepseek-ai/'));
const HOST_ROOTS = peers.length ? peers : ['@deepseek-ai/cordis', '@deepseek-ai/schemastery', '@deepseek-ai/dsh-web', '@deepseek-ai/dsh-tool-web', '@deepseek-ai/dsh-settings', '@deepseek-ai/dsh-timeout'];
const host = closure(HOST_ROOTS, (n) => { const m = pkgAt(ASAR_NM, n); return m ? { meta: m, dir: ASAR_NM + '/' + n } : null; });
let copied = 0, bytes = 0, files = 0;
const hostStale = [];
for (const name of host.seen) {
  const srcV = (pkgAt(ASAR_NM, name) || {}).version;
  const locV = (pkgAt(LOCAL_NM, name) || {}).version;
  if (locV === srcV) continue;                       // 版本一致 = 已经是运行时那一份
  hostStale.push(name + '@' + (locV || '缺失') + '≠' + srcV);
  if (CHECK) continue;
  const r = copyTree(ASAR_NM + '/' + name, LOCAL_NM + '/' + name);
  copied++; bytes += r.bytes; files += r.files;
}
console.log('① 宿主层：' + host.seen.length + ' 包（源 = app.asar）· '
  + (CHECK ? (hostStale.length ? hostStale.length + ' 个待更新' : '全部与运行时一致')
           : (copied ? copied + ' 个已更新' : '无需更新') + ' · ' + (bytes/1048576).toFixed(2) + ' MiB/' + files + ' 文件'));
if (CHECK && hostStale.length) console.log('    待更新: ' + hostStale.slice(0, 8).join(', ') + (hostStale.length > 8 ? ' …' : ''));

/* ---------- ② 插件自身依赖闭包：源 = profile 装机树 > asar ---------- */
const SOURCES = [PROFILE_NM, ASAR_NM];
const ownRoots = [...Object.keys(pkgJson.dependencies || {}), ...Object.keys(pkgJson.devDependencies || {})];
const own = closure(ownRoots, (n) => {
  for (const b of SOURCES) { const m = pkgAt(b, n); if (m) return { meta: m, dir: b + '/' + n }; }
  const m = pkgAt(LOCAL_NM, n); return m ? { meta: m, dir: LOCAL_NM + '/' + n, local: true } : null;
});
let ownCopied = 0, kept = 0;
const ownMissing = [];
for (const name of own.seen) {
  if (name.startsWith('@deepseek-ai/')) continue;     // 宿主层已由 ① 负责
  if (pkgAt(LOCAL_NM, name)) { kept++; continue; }    // 本地已有（含 react/react-dom 这类 devDep）一律不动
  ownMissing.push(name);
  if (CHECK) continue;
  copyTree((SOURCES.map((b) => pkgAt(b, name) && b).find(Boolean)) + '/' + name, LOCAL_NM + '/' + name);
  ownCopied++;
}
console.log('② 自身依赖：' + own.seen.length + ' 包 · 本地已有 ' + kept + ' · '
  + (CHECK ? (ownMissing.length ? ownMissing.length + ' 个待补' : '无缺口') : (ownCopied ? ownCopied + ' 个已补' : '无需补齐'))
  + (own.unresolved.length ? ' · 两个源都没有: ' + own.unresolved.join(' ') : ''));

if (CHECK) {
  const bad = hostStale.length + ownMissing.length;
  console.log(bad ? '✗ 开发测试树该重建了（' + bad + ' 项）—— 去掉 --check 跑一次' : '✓ 开发测试树与当前运行时一致（0 项待办）');
  process.exit(bad ? 1 : 0);
}
console.log('   （宿主层源: ' + ASAR + '）');
JSEOF

ELECTRON_RUN_AS_NODE=1 "$BIN" "$JS" "$PLUGIN" "$ASAR" "$PROFILE_NM" "$MODE"
rc=$?
if [ "$MODE" = "--check" ]; then exit "$rc"; fi

echo
echo '③ 验收：npm run test:unit'
cd "$PLUGIN" && npm run test:unit 2>&1 | tail -3