# MusicFree 插件与歌单备份

> 最后更新：2026-10-04 ｜ 对应 MusicFree 桌面版 0.0.8（`/usr/lib/musicfree`）

本目录是 MusicFree 插件的本地备份。插件实际装在 `~/.config/MusicFree/musicfree-plugins/`，
**运行中的 MusicFree 会清理这个目录**，所以恢复前必须先退出程序。

## 一、怎么恢复

```bash
~/scripts/MusicFree-歌单和插件/一键恢复.sh
```

脚本做三件事：检测到 MusicFree 在跑就先关掉（`pkill`，3 秒后还在就 `pkill -9`）→
把本目录所有 `*.js` 拷进 `~/.config/MusicFree/musicfree-plugins/` → 提示重开 MusicFree。

也可以双击 `恢复MusicFree插件.desktop`（带终端的桌面图标，`Terminal=true`）。

**歌单要手动导入**（脚本不处理歌单）：MusicFree 里「歌单 → 导入」，
选 `歌单-念心版.json`（推荐）或 `歌单.json`。

## 二、插件清单（6 个）

| 文件 | 类型 | 备注 |
|---|---|---|
| `酷我JHMS.js` | 音源·酷我（自带歌词） | |
| `酷我_念心.js` | 音源·酷我（自带歌词） | |
| `酷我-竹玥.js` | 音源·酷我 | ⚠️ 2026-08-21 实测已失效：接口要求 v5，公开渠道拿不到 v5。之后未复测 |
| `GD音乐台.js` | 音源·聚合（网易云等，自带歌词） | 走 gdstudio 音乐 API，可播网易云曲库（绕过本机 IP 风控） |
| `W音乐.js` | 音源·网易系 | 2026-08-21 新增，实测可搜可播。来源见下 |
| `qUjJ9rDU1d53RT8fLL0XQ.js` | 音源·B站 | 文件名是插件自带的 id，不是笔误 |

- `W音乐.js` 来源：https://cdn.jsdelivr.net/gh/ThomasBy2025/musicfree@main/plugins/wy.js
  （备用：raw.githubusercontent.com/ThomasBy2025/musicfree/refs/heads/main/plugins/wy.js）

### 装进去以后文件名可能变

MusicFree 按插件自带的 id 命名文件。本机实测：`W音乐.js` 装进插件目录后叫
`KdgTWk3HdgizttFAo1N8_.js`（内容一致，已比对 md5）。所以插件列表里出现哈希名文件是正常的，
备份目录里用可读名字只是为了好认。

## 三、歌单文件

| 文件 | 说明 |
|---|---|
| `歌单-念心版.json` | 酷我歌已改为念心源，推荐导入 |
| `歌单.json` | 原版 |

## 四、歌词窗口补丁 `patch_lrc.py`

修 MusicFree 0.0.8 的「外部歌词窗口 Object has been destroyed」报错。

- **改的是程序本体**：`/usr/lib/musicfree/resources/app/.webpack/main/index.js`，
  所以要 root（本机用 `~/scripts/desktop/gsudo python3 patch_lrc.py`）。
- 共 4 处，都是给歌词窗口的回调补 `isDestroyed` 保护：
  `showLyricWindow` 复位已销毁的旧引用、`closeLyricWindow` 跳过已销毁窗口、
  resize 回调与配置更新回调先判销毁再操作。
- **安全网**：每处特征串必须恰好匹配 1 次，否则整体中止、不写文件。
  已经打过补丁的文件匹配 0 次，所以重复运行只会中止，不会打乱。
- ⚠️ **MusicFree 升级会覆盖这个文件，补丁要重打**。`一键恢复.sh` 不处理它。
- 当前状态：2026-10-04 检查，4 处补丁都在位。

## 五、目录里还有什么

| 文件 | 用途 |
|---|---|
| `一键恢复.sh` | 关掉 MusicFree → 恢复 6 个插件 → 提示重开 |
| `恢复MusicFree插件.desktop` | 上面脚本的桌面启动图标（`Terminal=true`，Exec 里写死了 `~/scripts/...` 路径） |
| `patch_lrc.py` | 歌词窗口补丁，见上一节 |
| `__pycache__/` | `patch_lrc.py` 运行留下的缓存，已在 `.gitignore` 里忽略 |
