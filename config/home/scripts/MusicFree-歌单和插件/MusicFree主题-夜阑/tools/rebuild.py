#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""夜阑 — 主题重建 / 打包工具

做四件事：
  1. 从本机 Noctalia 当前色板算出整套颜色；
  2. 把它写进 index.css 的 PALETTE 段和 iframes/app.html 的 PALETTE 段（界面与动效同源，换壁纸一起变）；
  3. 用当前桌面壁纸重新生成 imgs/bg.jpg（双色调、压暗、模糊的底图）；
  4. 打包成 .mftheme（zip：根目录含 config.json / index.css）。

用法：
  ./build.sh                       # 用当前壁纸重建并打包
  ./build.sh --wall 某图.png        # 指定壁纸
  ./build.sh --no-palette          # 保留现有配色，只重做底图与打包
  ./build.sh --install             # 顺便（覆盖式）安装到 MusicFree 本地主题目录
  ./build.sh --theme-dir /tmp/副本  # 对另一份副本操作（试跑/CI 用；默认是脚本所在主题目录）

安全约定：
  * 替换色板段是**行锚定 + 整段替换**的，重复执行逐字节幂等（不会越写越歪）；
  * 只有在底图与打包都成功后才会保留对源文件的改写；中途失败会把源文件逐字节恢复；
  * 取不到壁纸时不会静默出包，而是 exit 2（除非显式 --allow-stale-bg）；
  * --install 的目标目录名固定取自 config.json 的 id，且断言只能落在 musicfree-themepacks 下；
    先解到临时目录、成功后再替换，并拒绝「把包打进即将被覆盖的目录」。
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HOME = Path.home()
THEME = Path(__file__).resolve().parent.parent
GTK_CSS = HOME / ".config" / "gtk-3.0" / "noctalia.css"
STARSHIP = HOME / ".cache" / "noctalia" / "starship-palette.toml"
INDEX_CSS = THEME / "index.css"
APP_HTML = THEME / "iframes" / "app.html"
CONFIG = THEME / "config.json"
THEMEPACK_ROOT = HOME / ".config" / "MusicFree" / "musicfree-themepacks"

START_RE = re.compile(r"^[ \t]*/\* >>> PALETTE-START[^\n]*$", re.M)
END_RE = re.compile(r"^[ \t]*/\* <<< PALETTE-END \*/[^\n]*$", re.M)


def rebind_theme_dir(path):
    """把整条链路重定向到另一份主题副本（默认仍是本文件所在的主题目录）"""
    global THEME, INDEX_CSS, APP_HTML, CONFIG
    THEME = Path(path).expanduser().resolve()
    INDEX_CSS = THEME / "index.css"
    APP_HTML = THEME / "iframes" / "app.html"
    CONFIG = THEME / "config.json"
    for p in (CONFIG, INDEX_CSS, APP_HTML):
        if not p.exists():
            raise SystemExit("[theme-dir] %s 看起来不是完整的主题目录（缺 %s）" % (THEME, p.name))


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(r, g, b):
    clamp = lambda v: max(0, min(255, int(round(v))))
    return "#%02x%02x%02x" % (clamp(r), clamp(g), clamp(b))


def mix(c1, c2, t):
    a, b = hex2rgb(c1), hex2rgb(c2)
    return rgb2hex(*[a[i] + (b[i] - a[i]) * t for i in range(3)])


def scale(c, f):
    return rgb2hex(*[v * f for v in hex2rgb(c)])


def read_gtk():
    if not GTK_CSS.exists():
        return {}
    text = GTK_CSS.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for name in ("accent_color", "accent_fg_color", "window_bg_color", "window_fg_color",
                 "card_bg_color", "error_bg_color", "popover_bg_color"):
        m = re.search(r"@define-color\s+%s\s+(#[0-9a-fA-F]{6})" % name, text)
        if m:
            out[name] = m.group(1).lower()
    return out


def read_starship():
    if not STARSHIP.exists():
        return {}
    text = STARSHIP.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for name in ("green", "blue", "cyan", "red", "text", "subtext0", "surface0", "base", "overlay0"):
        m = re.search(r'^\s*%s\s*=\s*"(#[0-9a-fA-F]{6})"' % name, text, re.M)
        if m:
            out[name] = m.group(1).lower()
    return out


def current_values():
    """从 index.css 现存的 PALETTE 段读出当前值，作为数据源缺失时的兜底"""
    text = INDEX_CSS.read_text(encoding="utf-8")
    m1, m2 = START_RE.search(text), END_RE.search(text)
    if not m1 or not m2:
        return {}
    vals = {}
    for m in re.finditer(r"--([A-Za-z]+)\s*:\s*([^;]+?)\s*!important;", text[m1.end():m2.start()]):
        vals[m.group(1)] = m.group(2)
    return vals


def build_palette():
    """角色映射：GTK 的 noctalia.css 是权威来源；starship 色板补 secondary/tertiary/subtext。
       Noctalia 把 Material You 的 secondary 放在 starship 的 blue 槽、tertiary 放在 cyan 槽。"""
    gtk, st, cur = read_gtk(), read_starship(), current_values()

    def fallback(key, default):
        return cur.get(key, default)

    primary = gtk.get("accent_color") or st.get("green") or fallback("primaryColor", "#a7c8ff")
    bg = gtk.get("window_bg_color") or st.get("base") or fallback("backgroundColor", "#111318")
    fg = gtk.get("window_fg_color") or st.get("text") or fallback("textColor", "#e1e2e9")
    surface = (gtk.get("card_bg_color") or gtk.get("popover_bg_color") or st.get("surface0")
               or fallback("backdropColor", "#1d2024"))
    subtext = st.get("subtext0") or st.get("overlay0") or "#8e9199"
    secondary = st.get("blue") or "#dbbce1"
    tertiary = st.get("cyan") or "#bdc7dc"
    error = gtk.get("error_bg_color") or st.get("red") or "#ffb4ab"

    return {
        "primary": primary,
        "secondary": secondary,
        "tertiary": tertiary,
        "base": bg,
        "deep": scale(bg, 0.62),
        "text": fg,
        "subtext": subtext,
        "surface": surface,
        "error": error,
    }


# 注意：这两个模板块**不以空白开头**，缩进由 replace_block 按原文标记行的缩进统一补齐，
# 这样重复构建是逐字节幂等的（曾经因为模板自带 2 空格，每跑一次就多缩进 2 格）。
INDEX_BLOCK = """/* >>> PALETTE-START · 由 build.sh 依据 Noctalia 当前色板重新生成（也可手改） */

/* ── 文字 ───────────────────────────────────────────── */
--textColor: {text} !important;
--textSecondaryColor: {tertiary} !important; /* 注：应用当前版本未消费此变量，保留以兼容 */
--placeholderColor: {subtext}99 !important;
--headerTextColor: {text} !important;
--headerPlaceholderColor: {subtext}8c !important;
--musicBarTextColor: {text} !important;

/* ── 底色与表面 ─────────────────────────────────────── */
--backgroundColor: {base} !important;
--backdropColor: {surface} !important;
--maskColor: {base}9e !important;
--shadowColor: rgba(0, 0, 0, 0.55) !important;
--windowBase: {deep} !important;

/* ── 强调色（Material You: primary / secondary / tertiary） ── */
--primaryColor: {primary} !important;
--secondaryColor: {secondary} !important; /* 色板源头；界面实际用下面的 secondarySoft */
--secondarySoft: {secondary}d9 !important;
--primaryGlow: {primary}8c !important;
--linkColor: {primary} !important;
--dangerColor: {error} !important;
--successColor: {tertiary} !important;
--infoColor: {tertiary} !important;

/* ── 描边 / 高亮（由主色加固定透明度派生） ─────────────── */
--dividerColor: {primary}24 !important;
--hairlineStrong: {primary}2e !important;
--accentSoft: {primary}38 !important;
--accentMid: {primary}6b !important;

/* ── 列表状态 ───────────────────────────────────────── */
--listHoverColor: {primary}14 !important;
--listActiveColor: {primary}29 !important;
--listEvenColor: {text}08 !important;

/* ── 毛玻璃层（底色 + 固定透明度：57≈34%、94≈58%） ───── */
--panelGlass: {base}57 !important;
--barGlass: {base}94 !important;

/* <<< PALETTE-END */"""

APP_BLOCK = """/* >>> PALETTE-START · 由 build.sh 依据 Noctalia 当前色板同步（与 index.css 同源，勿手改） */
:root {{
  --palette-primary: {primary};
  --palette-secondary: {secondary};
  --palette-tertiary: {tertiary};
  --palette-base: {base};
  --palette-deep: {deep};
  --palette-primary-soft: {primary}29;
  --palette-secondary-soft: {secondary}1f;
  --palette-veil-88: {base}e0;
  --palette-veil-56: {base}8f;
  --palette-veil-44: {base}70;
  --palette-vignette: {deep}8c;
}}
/* <<< PALETTE-END */"""


def replace_block(text, block, tag, pal):
    """行锚定地把整段 PALETTE 替换掉，并按原标记行的缩进重新缩进（幂等）"""
    m1, m2 = START_RE.search(text), END_RE.search(text)
    if not m1 or not m2 or m2.start() < m1.start():
        raise SystemExit("[palette] %s 里找不到 PALETTE-START/PALETTE-END 标记，拒绝改写" % tag)
    indent = re.match(r"[ \t]*", m1.group(0)).group(0)
    body = block.format(**pal).strip("\n")
    if indent:
        body = "\n".join((indent + ln) if ln.strip() else ln for ln in body.split("\n"))
    return text[:m1.start()] + body + text[m2.end():]


def resolve_out(out_arg=None):
    """默认产物名：<主题名>-v<版本>.mftheme —— 版本号取自 config.json 的 version 字段，
       所以每次发版只要改 config.json，包名自动带版本，不用记着手动改。"""
    if out_arg:
        return Path(out_arg)
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    name = re.sub(r"[^0-9A-Za-z\u4e00-\u9fff_-]", "", cfg.get("name", "theme"))
    ver = re.sub(r"[^0-9A-Za-z._-]", "", str(cfg.get("version", "0"))) or "0"
    return THEME.parent / ("%s-v%s.mftheme" % (name, ver))


def install_dest():
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    slug = re.sub(r"[^0-9A-Za-z_-]", "", cfg.get("id") or "") or "noctalia-night"
    return (THEMEPACK_ROOT.resolve() / (slug + "-noctalia-night")).resolve()


def check_installable(pack_path):
    """安装护栏：目标必须正好在 musicfree-themepacks 下，且包不能位于待覆盖目录之内"""
    pack_path = Path(pack_path).resolve()
    root = THEMEPACK_ROOT.resolve()
    dest = install_dest()
    if dest.parent != root:
        raise SystemExit("[install] 拒绝：目标目录 %s 不在 %s 下" % (dest, root))
    if pack_path == dest or dest in pack_path.parents:
        raise SystemExit("[install] 拒绝：包路径 %s 位于待覆盖目录 %s 之内，会先删后读" % (pack_path, dest))
    return dest


def pack(out_path=None):
    out_path = Path(out_path) if out_path is not None else resolve_out()
    names = ["config.json", "index.css"]
    for sub in ("iframes", "imgs"):
        d = THEME / sub
        if d.is_dir():
            for p in sorted(d.rglob("*")):
                if p.is_file():
                    names.append(str(p.relative_to(THEME)))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for n in names:
            z.write(THEME / n, n)
    print("[pack] 已打包:", out_path, "(%.0f KB)" % (out_path.stat().st_size / 1024))
    return out_path


def install(pack_path):
    pack_path = Path(pack_path).resolve()
    THEMEPACK_ROOT.mkdir(parents=True, exist_ok=True)
    root = THEMEPACK_ROOT.resolve()
    dest = check_installable(pack_path)

    # 先解到临时目录，成功后再替换，避免删完旧主题却装不上新的
    tmp = Path(tempfile.mkdtemp(prefix=".night-install-", dir=str(root)))
    try:
        with zipfile.ZipFile(pack_path) as z:
            z.extractall(tmp)
        if not (tmp / "config.json").exists() or not (tmp / "index.css").exists():
            raise SystemExit("[install] 拒绝：解出来的包缺少 config.json / index.css")
        if dest.exists():
            shutil.rmtree(dest)
        tmp.rename(dest)
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise
    print("[install] 已装入本地主题目录:", dest)
    return dest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wall", help="壁纸路径（默认问 Noctalia 当前壁纸）")
    ap.add_argument("--no-palette", action="store_true", help="不重写配色")
    ap.add_argument("--out", help="输出的 .mftheme 路径")
    ap.add_argument("--install", action="store_true", help="顺便覆盖安装到 MusicFree 本地主题目录")
    ap.add_argument("--allow-stale-bg", action="store_true", help="取不到壁纸时也继续（会沿用旧底图）")
    ap.add_argument("--theme-dir", help="对另一份主题副本操作（试跑/CI 用；默认脚本所在目录）")
    args = ap.parse_args()

    if args.theme_dir:
        rebind_theme_dir(args.theme_dir)
        print("[theme-dir] 本次操作对象：", THEME)

    wall = args.wall
    if not wall:
        try:
            wall = subprocess.run(["noctalia", "msg", "wallpaper-get"], capture_output=True,
                                  text=True, timeout=10).stdout.strip()
        except Exception:
            wall = ""
    if not wall or not Path(wall).exists():
        if not args.allow_stale_bg:
            print("[bg] 取不到当前壁纸（noctalia msg wallpaper-get 返回空）。\n"
                  "     拒绝继续：否则会出现「新配色 + 旧底图」的错配包。\n"
                  "     可以显式指定：./build.sh --wall /path/to/wallpaper.png\n"
                  "     或确知要用旧底图：./build.sh --allow-stale-bg", file=sys.stderr)
            return 2
        print("[bg] 警告：沿用过期的 imgs/bg.jpg（--allow-stale-bg）", file=sys.stderr)
        wall = None

    pal = build_palette()
    index_before = INDEX_CSS.read_text(encoding="utf-8")
    app_before = APP_HTML.read_text(encoding="utf-8")

    try:
        if args.no_palette:
            print("[palette] 跳过重写")
        else:
            INDEX_CSS.write_text(replace_block(index_before, INDEX_BLOCK, "index.css", pal), encoding="utf-8")
            APP_HTML.write_text(replace_block(app_before, APP_BLOCK, "iframes/app.html", pal), encoding="utf-8")
            print("[palette] 已同步 index.css 与 iframes/app.html："
                  "primary %s / secondary %s / base %s" % (pal["primary"], pal["secondary"], pal["base"]))

        if wall:
            shadow = scale(pal["base"], 0.55)
            highlight = mix(pal["primary"], pal["base"], 0.35)
            out_bg = THEME / "imgs" / "bg.jpg"
            try:
                subprocess.run(["magick", str(wall), "-resize", "1600x900^", "-gravity", "center",
                                "-extent", "1600x900", "-colorspace", "gray", "-blur", "0x16",
                                "-normalize", "+level", "10%,88%", "+level-colors",
                                shadow + "," + highlight,
                                "-modulate", "100,150,100",   # 提彩度：双色调否则偏灰（运行时不再叠 CSS filter，全部烘焙进图）
                                # 压中间调：保证不管壁纸原来多亮（雪景/逆光），出图都落在"夜"的亮度区间
                                "-level", "0%,100%,0.82",
                                "-quality", "86", str(out_bg)], check=True)
            except (subprocess.CalledProcessError, FileNotFoundError) as e:
                raise SystemExit("[bg] 底图生成失败（壁纸不是图片？没装 ImageMagick？）：%s" % e)
            print("[bg] 已按壁纸重新生成:", out_bg)

            # 远景视差层用的小尺寸模糊图：放大铺满即可，省掉运行时 filter: blur()
            out_soft = THEME / "imgs" / "bg-soft.jpg"
            try:
                subprocess.run(["magick", str(out_bg), "-resize", "240x135^", "-gravity", "center",
                                "-extent", "240x135", "-blur", "0x4", "-quality", "80",
                                str(out_soft)], check=True)
            except (subprocess.CalledProcessError, FileNotFoundError) as e:
                raise SystemExit("[bg] 远景模糊图生成失败：%s" % e)
            print("[bg] 已生成远景模糊图:", out_soft)

        out_path = resolve_out(args.out)
        if args.install:
            check_installable(out_path)   # 先拦，避免半成品落进待覆盖目录
        out = pack(out_path)
        if args.install:
            install(out)
    except BaseException:
        # 失败回滚：不让源文件停在「改了一半」的状态
        INDEX_CSS.write_text(index_before, encoding="utf-8")
        APP_HTML.write_text(app_before, encoding="utf-8")
        print("[rollback] 出错，index.css / app.html 已恢复原样", file=sys.stderr)
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
