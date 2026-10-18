#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""夜阑 — 对比度实测脚本（README 里那些数字就是它算出来的）

用法：
    python3 tools/contrast.py 截图.png [更多截图.png ...]

怎么拿到"纯背景"输入图（README 的 942×1012 就是这么来的）：
    * 本主题的动态背景是 iframes/app.html，它被应用注入成一整窗的底层；
    * 想单独量它，把主题目录复制一份到 /tmp，起个静态服务器，用浏览器按 942×1012 视口打开 app.html，
      等约 3 秒（让壁纸加载 + 动画稳定）后整屏截图即可；
      若直接以 http 打开，url("@/imgs/bg.jpg") 会 404 —— 那是应用运行时才做的别名替换，
      量测前请把 @/ 手动换成 file://<副本目录>/ 或用 data URI。
    * 别拿叠了文字的整窗截图来量，那会把文字像素算进亮端分位。

口径（很重要）：
    * 统计整张图所有像素的灰度分位：p50 / p95 / p99 / p99.5；p99.5 比 p99 稳（稀疏高亮点密集时 p99 会贴到 p100）；
    * 另外给出「低于 4.5:1 的像素占比」——这比单点最坏值更能说明实际影响面；
    * 对比度按 WCAG 2.x 相对亮度公式算；文字色从 index.css 的 PALETTE 段读取。
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

THEME = Path(__file__).resolve().parent.parent
INDEX_CSS = THEME / "index.css"
THRESHOLD = 4.5


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum_from_hex(h):
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)


def contrast(l1, l2):
    a, b = max(l1, l2), min(l1, l2)
    return (a + 0.05) / (b + 0.05)


def text_colors():
    text = INDEX_CSS.read_text(encoding="utf-8")
    start = re.search(r"^[ \t]*/\* >>> PALETTE-START[^\n]*$", text, re.M)
    end = re.search(r"^[ \t]*/\* <<< PALETTE-END \*/[^\n]*$", text, re.M)
    seg = text[start.end():end.start()]
    out = {}
    for key in ("textColor", "textSecondaryColor", "primaryColor"):
        m = re.search(r"--%s\s*:\s*(#[0-9a-fA-F]{6})" % key, seg)
        if m:
            out[key] = m.group(1)
    return out


def gray_bytes(png):
    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as f:
        raw = f.name
    subprocess.run(["magick", str(png), "-colorspace", "gray", "-depth", "8", "gray:" + raw], check=True)
    data = Path(raw).read_bytes()
    Path(raw).unlink()
    return data


def percentile(sorted_vals, p):
    n = len(sorted_vals)
    return sorted_vals[min(n - 1, int(n * p / 100))]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    colors = text_colors()
    print("文字色（取自 index.css）：", ", ".join("%s=%s" % kv for kv in colors.items()))
    print("注：应用里列表副标题（艺人行）实际是 .music-artist div{opacity:.8} 的主文字色，")
    print("    并不使用 --textSecondaryColor（该变量在应用 bundle 里引用数为 0），下面按真实口径单独给一行。")
    for arg in sys.argv[1:]:
        png = Path(arg)
        vals = sorted(gray_bytes(png))
        pcts = {p: percentile(vals, p) for p in (5, 50, 90, 95, 99, 99.5, 100)}
        print("\n%s  像素 %d" % (png, len(vals)))
        print("  灰度分位:", ", ".join("p%s=%d" % (k, v) for k, v in pcts.items()))
        for key, hexv in colors.items():
            L = lum_from_hex(hexv)
            line = "  %-18s(relLum %.5f) vs 背景: " % (key, L)
            line += "  ".join("p%s=%.2f:1" % (k, contrast(L, srgb_to_lin(pcts[k] / 255.0)))
                              for k in (50, 95, 99, 99.5, 100))
            below = sum(1 for v in vals if contrast(L, srgb_to_lin(v / 255.0)) < THRESHOLD)
            line += "   低于 %s:1 的像素 %.4f%% (%d 个)" % (THRESHOLD, 100.0 * below / len(vals), below)
            print(line)
        if "textColor" in colors:
            # 应用真实口径：艺人行 = 主文字色 @80% 不透明，合成后仍然是"浅色文字压在背景上"
            r0, g0, b0 = (int(colors["textColor"][i:i + 2], 16) / 255.0 for i in (1, 3, 5))
            def blended(gray):
                bg = gray / 255.0
                rr, gg, bb = (0.8 * c + 0.2 * bg for c in (r0, g0, b0))
                return 0.2126 * srgb_to_lin(rr) + 0.7152 * srgb_to_lin(gg) + 0.0722 * srgb_to_lin(bb)
            line = "  %-18s vs 背景: " % "textColor@80%(艺人行)"
            line += "  ".join("p%s=%.2f:1" % (k, contrast(blended(pcts[k]), srgb_to_lin(pcts[k] / 255.0)))
                              for k in (50, 95, 99, 99.5))
            below = sum(1 for v in vals if contrast(blended(v), srgb_to_lin(v / 255.0)) < THRESHOLD)
            line += "   低于 %s:1 的像素 %.4f%% (%d 个)" % (THRESHOLD, 100.0 * below / len(vals), below)
            print(line)
        print("  → 判据：p99.5 处 ≥4.5:1 视为通过（WCAG AA 小字）；另看『低于 4.5:1 的像素占比』评估实际影响面")
    return 0


if __name__ == "__main__":
    sys.exit(main())
