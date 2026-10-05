#!/usr/bin/env bash
# patch-plugin-icon-renames.sh —— 通用修补：插件按旧名引用宿主图标，导致 React #130
# 整块 UI 崩掉（不是静默失败，是渲染期抛错）。
#
# 事实（2026-09-22 首次取证；2026-09-26 在桌面版上重新取证）：
#   * 宿主 @deepseek-ai/dsh-client-ui-primitives 的图标导出由「尺寸后缀」制改为
#     字重档制：旧 `IconXxx16` / `IconXxx14` → 新 `IconXxxRegular`（另有 Medium /
#     Artwork），**旧名一个不剩**。2026-09-26 从桌面版 asar 里的
#     `dsh/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js` 实测：
#     导出 279 个符号，`Icon*Regular` **99 个**，`Icon*(16|14)` **0 个**。
#   * 插件用
#       (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconSparkle16, {...})
#     这种形态引用（1.58 起打包器还会改成**解构后裸用** `IconSparkle16`）⇒ 解构到
#     undefined ⇒ React 把 undefined 当组件渲染 ⇒ **Minified React error #130**
#     （args[]=undefined）⇒ 该 UI 整块崩成空白/恢复面板。
#   * **这是"导出改名"不是"删 API"**：inject 不报 pending、服务端 web.log 可以完全干净、
#     0 激活失败 ⇒ **只看服务端会判成"升级无碍"**。必须开页面看控制台。
#   * 历史：1.47.0 / 1.55.0 / 1.58.0 / 1.59.0 的 client bundle 用**成员访问或裸用**的旧名，
#     确实会 React #130 ⇒ 当时的 dshmarket 市场整块被恢复面板替换，只能本地补丁。
#   * **2026-09-26 实测：dshmarket 1.65.3 上游已自带兼容层** —— `ICON_ALIASES` +
#     `pickIcon("IconXxxRegular","IconXxx16")` 自己把旧名 resolve 到宿主的新导出，
#     **零成员访问** ⇒ 不会 #130。旧口径（"上游未修、随时崩"）**作废**。
#   * 因此本脚本**跳过自带兼容层的 bundle**（检测 ICON_ALIASES / pickIcon / resolveIcon），
#     并且**不再改写字符串字面量**里的旧名（别名表）；要强行处理：ICON_PATCH_FORCE=1。
#
# 桌面版时代为什么**保留**这个补丁（定位已从"必需"变为"防回归"，2026-09-26）：
#   * 桌面版把插件装进 profile 的 node_modules（`~/.dsh/profiles/desktop/node_modules`），
#     用的是 pnpm 内容寻址仓库的**硬链接**。
#   * 桌面版的**插件页 / 市场更新插件**时会跑一轮 pnpm install，从 store 重新硬链 ⇒ 任何本地改动都被冲掉。
#   * 一旦**将来**某个版本的某个插件又用回旧名硬引用，现象仍是市场/面板 React #130，而服务端日志干净
#     ⇒ 本脚本是那种回归的第一道闸（对 1.65.3 判定为"已经是修好的状态"）。
#   * 桌面版本体在 app.asar 里、**不可打补丁**；所以本目录的补丁只针对 profile 插件。
#
# 本机受害面（史料 + 现状）：
#   * dshmarket —— 1.58.0 时代确实崩过（成员访问旧名）；**1.65.3 起上游自带兼容层，不再受害**。
#   * （史料）dsh-better-sidebar —— 已于 2026-09-24 随插件卸载，不再参与。
#
# 目标 profile 的判定（2026-09-26 改版：web 时代 → 桌面版时代）：
#   1. 环境变量 `DSH_PROFILE_NM` 已设置 ⇒ 用它（指向该 profile 的 node_modules）；
#   2. 否则 `~/.dsh/profiles/desktop/node_modules` 存在 ⇒ 用它（**桌面版是当前唯一形态**）；
#   3. 否则回退 `~/.dsh/profiles/web/node_modules`（历史 npm/CLI 时代）。
#   实际用的是哪一个**一定会打印出来**，不许猜。
#
# 宿主导出表的判定（桌面版 CLI 已删除 ⇒ PATH 上没有 dsh，旧推导必然落空）：
#   1. 环境变量 `DSH_PRIM` 已设置 ⇒ 直接读该文件；
#   2. PATH 上还有 dsh ⇒ 按 npm 布局推导（历史形态，保留兼容）；
#   3. 否则读桌面版 asar 内的
#      `<asar>/dsh/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js`
#      （asar 路径可用环境变量 `DSH_DESKTOP_ASAR` 覆盖；默认
#      `/usr/lib/deepseek-harness-desktop/resources/app.asar`）。
#      2026-09-26 实测：asar 内该文件 sha256 与 asar 头登记的哈希一致 ⇒ 读到的就是运行时那一份。
#
# 映射规则：`IconXxx<16|14>` → `IconXxxRegular`，**只在该目标确实存在于宿主导出表时**才替换
# （脚本内置存在性校验，映射不成立就跳过并报告，绝不猜）。只替换带
# `_deepseek_ai_dsh_client_ui_primitives.` 前缀的引用，或"解构后裸用"的裸名，不误伤同名局部变量。
#
# 用法：
#   patch-plugin-icon-renames.sh            # 应用（幂等）
#   patch-plugin-icon-renames.sh --check    # 只看状态，不改动
#   patch-plugin-icon-renames.sh --revert   # 从 .orig-iconrename 还原
#
# 目标文件在 profile 的 node_modules 里 ⇒ 插件升级 / 市场更新 / `dsh plugin remove+add`
# 会冲掉它。**改完不用重启**：客户端 bundle 由 dsh-client-hmr 热重载（页面若仍显示旧界面
# 请硬刷新）；但插件**宿主半**的更新仍需重启桌面应用才生效。
set -uo pipefail

MODE="apply"
case "${1:-}" in
  --check)  MODE="check" ;;
  --revert) MODE="revert" ;;
  "")       ;;
  -h|--help) sed -n '2,80p' "$0"; exit 0 ;;
  *) echo "未知参数: $1（可用 --check / --revert）" >&2; exit 2 ;;
esac

BACKUP_SUFFIX=".orig-iconrename"

log() { printf '%s\n' "$*"; }

# ------------------------------------------------ 目标 profile（桌面版优先）
if [[ -n "${DSH_PROFILE_NM:-}" ]]; then
  PROFILE_NM="$DSH_PROFILE_NM"
  PROFILE_SRC="环境变量 DSH_PROFILE_NM"
elif [[ -d "$HOME/.dsh/profiles/desktop/node_modules" ]]; then
  PROFILE_NM="$HOME/.dsh/profiles/desktop/node_modules"
  PROFILE_SRC="自动探测（桌面版 profile desktop）"
elif [[ -d "$HOME/.dsh/profiles/web/node_modules" ]]; then
  PROFILE_NM="$HOME/.dsh/profiles/web/node_modules"
  PROFILE_SRC="回退（旧 web profile）"
else
  PROFILE_NM="$HOME/.dsh/profiles/web/node_modules"
  PROFILE_SRC="回退（旧 web profile，目录不存在）"
fi

# ------------------------------------------------ 宿主导出表（asar / npm / 覆盖）
PRIM=""
PRIM_SRC=""
if [[ -n "${DSH_PRIM:-}" ]]; then
  PRIM="$DSH_PRIM"; PRIM_SRC="环境变量 DSH_PRIM"
else
  # 从 PATH 上的 dsh 现解"当前生效安装"的包根（仅历史 npm/源码安装形态下存在）
  _dsh_real="$(readlink -f "$(command -v dsh 2>/dev/null)" 2>/dev/null || true)"
  DSH_PKG_ROOT=""
  if [[ -n "$_dsh_real" ]]; then
    DSH_PKG_ROOT="$(dirname "$(dirname "$_dsh_real")")"
    [[ -f "$DSH_PKG_ROOT/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js" ]] || {
      # 兜底：按 /(lib|bin)/<file> 反推
      _root="$(printf '%s' "$_dsh_real" | sed -E 's|/(lib|bin)/[^/]+$||')"
      [[ -n "$_root" ]] && DSH_PKG_ROOT="$_root"
    }
    if [[ -f "$DSH_PKG_ROOT/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js" ]]; then
      PRIM="$DSH_PKG_ROOT/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js"
      PRIM_SRC="PATH 上的 dsh 安装树（npm 形态）"
    fi
  fi
  if [[ -z "$PRIM" ]]; then
    for _a in "${DSH_DESKTOP_ASAR:-}" \
              "/usr/lib/deepseek-harness-desktop/resources/app.asar" \
              "${XDG_DATA_HOME:-$HOME/.local/share}/deepseek-harness-desktop/resources/app.asar"; do
      [[ -n "$_a" && -f "$_a" ]] && { PRIM="asar:$_a"; PRIM_SRC="桌面版 asar"; break; }
    done
  fi
fi

log "profile: $PROFILE_NM"
log "  来源: $PROFILE_SRC"
if [[ -z "$PRIM" ]]; then
  log "宿主导出表: 找不到（PATH 无 dsh，且未找到桌面版 app.asar）。"
  log "  可用 DSH_PRIM=<primitives 包内 lib/index.js 路径> 或 DSH_DESKTOP_ASAR=<app.asar 路径> 显式指定；跳过，不视为失败。"
  exit 0
fi
log "宿主导出表: $PRIM"
log "  来源: $PRIM_SRC"

if [[ ! -d "$PROFILE_NM" ]]; then
  log "找不到 $PROFILE_NM（profile 未安装？），跳过。"
  exit 0
fi

# ---------------------------------------------------------------- revert
if [[ "$MODE" == "revert" ]]; then
  n=0
  while IFS= read -r bak; do
    tgt="${bak%"$BACKUP_SUFFIX"}"
    cp -p "$bak" "$tgt" && rm -f "$bak" && { log "已还原: ${tgt#"$PROFILE_NM"/}"; n=$((n+1)); }
  done < <(find "$PROFILE_NM" -maxdepth 4 -name "*$BACKUP_SUFFIX" -type f 2>/dev/null)
  log "还原完成：$n 个文件。"
  exit 0
fi

# ------------------------------------------------------- scan / apply / check
# node 侧负责：读取宿主导出表 → 发现 bundle → 计算待改数 → （apply 时）备份并改名
RESULT="$(MODE="$MODE" PROFILE_NM="$PROFILE_NM" PRIM="$PRIM" BACKUP_SUFFIX="$BACKUP_SUFFIX" node -e '
const fs = require("fs"), path = require("path");
const { MODE, PROFILE_NM, PRIM, BACKUP_SUFFIX } = process.env;
const PREFIX = "_deepseek_ai_dsh_client_ui_primitives.";
const ASAR_REL = "dsh/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js";

/** 读桌面版 app.asar 内的文件（Electron asar：16 字节 pickle 头 + JSON 头 + 数据段） */
function readAsar(asarPath, rel) {
  const fd = fs.openSync(asarPath, "r");
  try {
    const head = Buffer.alloc(16);
    fs.readSync(fd, head, 0, 16, 0);
    const jsonLen = head.readUInt32LE(12);
    if (jsonLen <= 0 || jsonLen > 512 * 1024 * 1024) return null;
    const meta = Buffer.alloc(jsonLen);
    fs.readSync(fd, meta, 0, jsonLen, 16);
    const header = JSON.parse(meta.toString("utf8"));
    let cur = header;
    for (const part of rel.split("/")) {
      cur = cur && cur.files && cur.files[part];
      if (!cur) return null;
    }
    if (typeof cur.offset !== "string") return null;
    const buf = Buffer.alloc(cur.size);
    fs.readSync(fd, buf, 0, cur.size, 16 + jsonLen + Number(cur.offset));
    return buf.toString("utf8");
  } finally { fs.closeSync(fd); }
}

let hostSrc = "", primText = null;
if (PRIM.startsWith("asar:")) {
  const asarPath = PRIM.slice(5);
  primText = readAsar(asarPath, ASAR_REL);
  hostSrc = asarPath + "!" + ASAR_REL;
} else {
  primText = fs.readFileSync(PRIM, "utf8");
  hostSrc = PRIM;
}
if (primText === null) {
  process.stdout.write("ERR|宿主导出表读取失败（asar 内找不到 " + ASAR_REL + "）：" + PRIM + "\n");
  process.exit(0);
}

const m = primText.match(/export \{([^}]*)\}/);
if (m === null) { process.stdout.write("ERR|宿主导出表解析失败（无 export 块）：" + hostSrc + "\n"); process.exit(0); }
const host = new Set(m[1].split(",").map((s) => s.split(" as ").pop().trim()).filter(Boolean));

/** 枚举所有装机插件的候选客户端 bundle：<pkg>/lib/*.js 与 <pkg>/client/*.js */
function bundles() {
  const out = [];
  const pushPkg = (dir) => {
    for (const sub of ["lib", "client"]) {
      const d = path.join(dir, sub);
      let ents; try { ents = fs.readdirSync(d); } catch { continue; }
      for (const f of ents) if (f.endsWith(".js")) out.push(path.join(d, f));
    }
  };
  let tops; try { tops = fs.readdirSync(PROFILE_NM, { withFileTypes: true }); } catch { return out; }
  for (const e of tops) {
    if (!e.isDirectory()) continue;
    if (e.name.startsWith("@")) {
      const sc = path.join(PROFILE_NM, e.name);
      let subs; try { subs = fs.readdirSync(sc, { withFileTypes: true }); } catch { continue; }
      for (const s of subs) if (s.isDirectory()) pushPkg(path.join(sc, s.name));
    } else pushPkg(path.join(PROFILE_NM, e.name));
  }
  return out;
}

const esc = (s) => s.replace(/[.*+?^$\{}()|[\]\\]/g, "\\$&");
const FORCE = process.env.ICON_PATCH_FORCE === "1";
const compatFiles = [];
/** 标记“位于字符串字面量内”的字节：别名表里的字符串旧名不该被改名。 */
function stringMask(s) {
  const m = new Uint8Array(s.length);
  let q = 0, inEsc = false;
  for (let i = 0; i < s.length; i++) {
    const cc = s.charCodeAt(i);
    if (q === 0) { if (cc === 34 || cc === 39 || cc === 96) { q = cc; m[i] = 1; } }
    else { m[i] = 1; if (inEsc) inEsc = false; else if (cc === 92) inEsc = true; else if (cc === q) q = 0; }
  }
  return m;
}
let files = 0, totalApplied = 0, totalPending = 0, totalLeftover = 0, unmappable = [];
const leftoverNames = new Set();
const lines = [];

for (const file of bundles()) {
  let text; try { text = fs.readFileSync(file, "utf8"); } catch { continue; }
  if (!text.includes(PREFIX)) continue;
  // 上游自带兼容层的 bundle 一律跳过（2026-09-26 实测 dshmarket 1.65.3）：
  // 它自己用 pickIcon("IconXxxRegular","IconXxx16") / ICON_ALIASES 把旧名映射到宿主新导出，
  // **零成员访问** ⇒ 不会 React #130。对这种文件"改名"只会篡改上游已经正确的代码
  // （连别名表里的字符串字面量都会被一起改掉），属误报。要强行处理：ICON_PATCH_FORCE=1。
  if (!FORCE && /ICON_ALIASES|pickIcon\(|resolveIcon\(/.test(text)) {
    compatFiles.push(path.relative(PROFILE_NM, file));
    files++;
    continue;
  }
  // 只在**非字符串**区间替换。
  const mask = stringMask(text);
  files++;

  // 前缀**可选**：打包器按上下文分配局部别名，各版本形态不同——
  //   1.55 成员访问：`_deepseek_ai_dsh_client_ui_primitives.IconFoo16`
  //   1.58 解构后裸用：`const { IconFoo16 } = _deepseek_ai_dsh_client_ui_primitives;` … `IconFoo16`
  // 只认成员访问会一处都匹配不到、静默误报"已经是修好的状态"（2026-09-23 实测：
  // 装机文件与上游 tarball 逐字节相同、138 处旧名，脚本却报无需改动）。
  // 捕获前缀本身并在替换时**原样放回**：裸用法必须还是裸的，补回 `primitives.`
  // 会写出 `const { primitives.IconFooRegular } = …` 这种语法错误（实测被语法闸拦下）。
  const re = new RegExp("(" + esc(PREFIX) + ")?(Icon[A-Za-z0-9_$]*?(?:16|14))\\b", "g");
  const names = new Set();
  let h; while ((h = re.exec(text)) !== null) names.add(h[2]);
  re.lastIndex = 0;
  if (names.size === 0) continue;

  let changed = 0, pending = 0;
  const next = text.replace(re, (whole, pfx, name, offset) => {
    if (mask[offset]) return whole;             // 字符串字面量（别名表）里的一律不动
    const mapped = name.replace(/(16|14)$/, "Regular");
    if (!host.has(mapped)) { unmappable.push(name + "(无 " + mapped + ")"); return whole; }
    pending++; changed++;
    return (pfx || "") + mapped;
  });
  totalPending += pending;
  // 独立复核：改完后**原样数一遍**残留旧名（不复用上面的正则——同一个错误既会造成
  // 漏改、又会造成"已修好"的误报，工具自证必须换一种算法）。
  // 只有**本文件没有本地声明**的残留才算可疑：插件自带的图标（如 better-sidebar 自己的
  // IconVscode16 / IconPdfOutline16）本来就是合法名字，宿主两个名字都没有，不该报红。
  for (const name of new Set(next.match(/\bIcon[A-Za-z0-9_$]*?(?:16|14)\b/g) || [])) {
    const local = new RegExp("(?:function|class|const|let|var)\\s+" + esc(name) + "\\b").test(next);
    if (!local) { totalLeftover += 1; leftoverNames.add(name); }
  }
  if (pending === 0) continue;

  const rel = path.relative(PROFILE_NM, file);
  if (MODE === "check") { lines.push("  待改 " + pending + " 处: " + rel); continue; }

  const bak = file + BACKUP_SUFFIX;
  if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);          // 只在首次留"上游原样"基准
  fs.writeFileSync(file, next);
  totalApplied += pending;
  lines.push("  已改 " + pending + " 处: " + rel);
}

if (compatFiles.length > 0)
  lines.push("  跳过 " + compatFiles.length + " 个上游自带兼容层的 bundle（" + compatFiles.join(", ") + "）—— 它们自己 resolve 旧名，不需要本补丁");
// 第 7 个字段 = 跳过数（自带兼容层的 bundle）。审查发现：只报"已是修好的状态"
// 会让人以为 3 个 bundle 都干净，实际其中 1 个是"没检查"（被跳过）。
process.stdout.write("OK|" + files + "|" + totalApplied + "|" + totalPending + "|" +
  totalLeftover + "|" + [...new Set(unmappable)].join(",") + "|" + compatFiles.length + "\n" +
  "SRC|" + hostSrc + "\n" +
  lines.join("\n") + "\n");
' 2>&1)"

if [[ "$RESULT" == ERR\|* ]]; then
  log "${RESULT#ERR|}"
  exit 0
fi
if [[ "$RESULT" != OK\|* ]]; then
  log "扫描失败："
  printf '%s\n' "$RESULT" | tail -5
  exit 1
fi

# 结果分三段：第一行 stats、第二行 SRC|、其余为逐文件明细。
# 注意：不能只按"去掉首行"取 body——命令替换会吃掉结尾换行，body 为空时
# RESULT 里根本没有换行（旧实现会把 "OK|8|0|0|" 这种内部串漏进用户输出）。
HDR="${RESULT%%$'\n'*}"
REST="${RESULT#*$'\n'}"
[[ "$REST" == "$HDR" ]] && REST=""
SRC_LINE=""
BODY="$REST"
if [[ "$REST" == SRC\|* ]]; then
  if [[ "$REST" == *$'\n'* ]]; then
    SRC_LINE="${REST%%$'\n'*}"
    BODY="${REST#*$'\n'}"
  else
    SRC_LINE="$REST"
    BODY=""
  fi
fi
[[ -n "$SRC_LINE" ]] && log "  实际读取: ${SRC_LINE#SRC|}"
IFS='|' read -r _ NFILES APPLIED PENDING LEFTOVER UNMAPPABLE SKIPPED <<<"$HDR"
SKIPPED="${SKIPPED:-0}"

[[ -n "$BODY" ]] && printf '%s\n' "$BODY"
[[ -n "${UNMAPPABLE:-}" ]] && log "注意：以下旧名找不到对应 ...Regular，已跳过（需人工核对）：$UNMAPPABLE"

# ------------------------------------------------- 语法闸 + 失败自动回滚
if [[ "$MODE" == "apply" && "$APPLIED" -gt 0 ]]; then
  bad=0
  while IFS= read -r bak; do
    tgt="${bak%"$BACKUP_SUFFIX"}"
    if ! node --check "$tgt" >/dev/null 2>&1; then
      log "语法闸失败，回滚：${tgt#"$PROFILE_NM"/}"
      cp -p "$bak" "$tgt"
      bad=$((bad+1))
    fi
  done < <(find "$PROFILE_NM" -maxdepth 4 -name "*$BACKUP_SUFFIX" -type f 2>/dev/null)
  if [[ "$bad" -gt 0 ]]; then
    log "有 $bad 个文件未通过语法闸，已还原为上游原样。"
    exit 1
  fi
fi

case "$MODE" in
  check)
    if [[ "$PENDING" -gt 0 ]]; then
      log "检测到 $PENDING 处旧图标名引用（$NFILES 个 bundle）⇒ 对应 UI 会报 React #130。"
      log "修复: bash $0"
      exit 0
    fi
    if [[ "${LEFTOVER:-0}" -gt 0 ]]; then
      log "★ 扫描了 $NFILES 个 bundle，无**可映射**旧名，但仍有 $LEFTOVER 处 Icon*16/14 残留（宿主无对应 ...Regular）——需人工核对，勿当成已修好。"
      exit 1
    fi
    log "已经是修好的状态（$NFILES 个 bundle 无旧名引用）。"
    [[ "${SKIPPED:-0}" -gt 0 ]] && log "  其中 $SKIPPED 个 bundle 因上游自带兼容层跳过（未检查，非已修好）。"
    ;;
  apply)
    if [[ "$APPLIED" -gt 0 ]]; then
      log "已修正 $APPLIED 处图标引用（IconXxx16/14 → IconXxxRegular），备份后缀 $BACKUP_SUFFIX。"
      log "客户端 bundle 由 dsh-client-hmr 热重载，通常无需重启；页面若仍显示旧界面请硬刷新。"
    elif [[ "${LEFTOVER:-0}" -gt 0 ]]; then
      log "★ 扫描 $NFILES 个 bundle，无可映射改动，但仍有 $LEFTOVER 处 Icon*16/14 残留（宿主无对应 ...Regular）——需人工核对。"
      exit 1
    else
      log "已经是修好的状态（扫描 $NFILES 个 bundle，无需改动）。"
      [[ "${SKIPPED:-0}" -gt 0 ]] && log "  其中 $SKIPPED 个 bundle 因上游自带兼容层跳过（未检查，非已修好）。"
    fi
    ;;
esac
