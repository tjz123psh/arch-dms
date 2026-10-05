# Review: wechat-universal-bwrap

## Status

- Decision: **reviewed AUR recipe with pinned upstream deb**.
- Replaces the former `wechat-appimage` recipe: the operator's machine now runs
  the bwrap package (AppImage + fuse2 dropped 2026-09-16).

## Provenance

- AUR origin: `https://aur.archlinux.org/wechat-universal-bwrap.git`
- AUR commit: `c72f754308882c3ea54097d24821d82664022c17`（2026-10-05 对齐上游时的 HEAD）
- Upstream version / license: `4.1.13.23-1` / `LicenseRef-wechat-license`
  (bundled `wechat-license` file).
- Pinned payload (`source_x86_64`, makepkg renames it to the recipe's deb name):
  `https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb` with
  SHA-256 `b7d0f8d53e9f648bc2c77a6096a04100d008f2d9f0d3988a2a4859b5992aca0a`
  (declared in the PKGBUILD；231,359,624 B，2026-10-05 实测字节复核，与上游一致)。

## 更新记录

### 2026-10-05：4.1.13.9 → 4.1.13.23（离线缓存构建时发现的真问题）

- **触发**：重建离线缓存时 `wechat-universal-4.1.13.9-x86_64.deb` 校验失败
  （实测 `b7d0f8d5…` ≠ 锁定的 `096865e0…`）。根因是腾讯那个**不带版本号的通用 URL**
  被换成了新版本：下载到的 deb 内嵌 `Version: 4.1.13.23`
  （`Last-Modified: 2026-09-18`，231,359,624 B）。**旧锁定的哈希已死 ⇒ 任何走钉版 recipe
  的构建（离线全量）都会在 checksum 处失败**，不是网络问题。
- **做法**：按"以最新上游版本为准"对齐 AUR 当前 recipe（commit `c72f7543`）——只改
  `pkgver` 与三个 `sha256sums_*`，保留本项目的 `arch=('x86_64')` 等本地改造。
  x86_64 哈希**用实测字节复核**（与上游/AUR 一致），aarch64/loong64 取上游值（本项目不构建）。
- **口径提醒**：该 URL 无版本号，上游每发一版就会让本地锁定失效；**每次重建离线缓存或
  上游发新版时都要复核这里的 sha256**（fetch-aur-sources.sh 的 `dl` 行同步）。
- 佐证：宿主机当前装的仍是 `4.1.13.9-1`（本 recipe 自本条起跟上游，不再与宿主版本对齐）。

## Local changes from the AUR recipe

- `arch` restricted to `x86_64` (this project's target machine).
- Removed the two AUR-side release-scraping helpers
  (`fetch_tencent_wechat_release.sh`, `fetch_uos_wechat_release.py`): they are
  not `source` entries and are only used to update the recipe by hand; the
  pinned deb URL + SHA-256 replace them for this project.
- Kept: `wechat-universal.sh` launcher, desktop entry, install script,
  `libuosdevicea` compatibility shim and the license file.

## Expected output

- Package: `wechat-universal-bwrap 4.1.13.23-1 (x86_64)`
- Launcher: `/usr/bin/wechat-universal`
