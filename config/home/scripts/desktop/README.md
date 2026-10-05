# desktop —— 桌面环境辅助脚本

> 最后更新：2026-10-04 ｜ 环境：niri + Hyprland 双窗口管理器（本机 ASUS TUF A15 / Arch）

## 一、是什么

niri 与 Hyprland 共用的桌面辅助脚本集合，覆盖权限提权、快捷键速查、退出确认、VM 测试模式、
触摸板开关、剪贴板互通、截图音效等日常操作。

**怎么被调用**：脚本不假设自己的安装位置——键位绑定和 systemd 服务里写的是绝对路径
`/home/pang/scripts/desktop/<脚本名>`；需要从 PATH 直接敲的几个，在 `~/.local/bin/` 建了软链
（`gsudo`、`fuzzel-askpass`、`niri-keys`、`hypr-keys`、`niri-touchpad-toggle`、`hypr-touchpad-toggle`）。

## 二、脚本清单

| 脚本 | 作用 | 触发方式 |
|---|---|---|
| `gsudo` | 图形化 sudo：用 fuzzel 弹框输入密码后执行命令（`sudo -A`） | 手动 |
| `fuzzel-askpass` | gsudo 的 `SUDO_ASKPASS` 助手：fuzzel 掩码密码框，密码打到 stdout | 由 gsudo 调用 |
| `niri-keys` | niri 快捷键速查（解析 keybinds.kdl，kitty + fzf 交互搜索） | niri `Mod+/` |
| `hypr-keys` | Hyprland 快捷键速查（读 `~/.config/hypr/keybinds.list` 清单） | Hyprland `Mod+/` |
| `niri-quit` | niri 退出确认菜单（term-menu 同款 fzf 界面，默认选中「取消」） | niri `Mod+Shift+E` |
| `hypr-quit` | Hyprland 退出确认菜单（同上；确认后 `hyprctl dispatch 'hl.dsp.exit()'`） | Hyprland `Win+Shift+E` |
| `niri-vmtest-gen` | 生成 niri VM 测试配置（快捷键全禁，只留 Win+Shift+D 开关键） | 改完正常配置后手动跑一次 |
| `hypr-vmtest-gen` | 生成 Hyprland VM 测试配置（同上） | 改完正常配置后手动跑一次 |
| `hypr-vmtest-toggle` | 切换 Hyprland 正常 / VM 测试配置（符号链接 + `hyprctl reload`） | Hyprland `Win+Shift+D` |
| `hypr-magnifier` | Hyprland 原生屏幕放大镜（1x → 2x → 3x 循环，不走截屏回环） | Hyprland `Alt+A` |
| `niri-touchpad-toggle` | 开关内置触摸板（改写 `touchpad-state.kdl` 的 `off` 行后重载配置） | niri `XF86TouchpadToggle`（Fn+F10） |
| `hypr-touchpad-toggle` | 开关内置触摸板（`hyprctl eval` 改设备 `enabled`） | Hyprland `XF86TouchpadToggle`（Fn+F10） |
| `clipboard-x11-bridge` | 把 Wayland 剪贴板镜像到 X11 侧，让 QQ / 微信等 X11 应用能粘贴 | systemd user 服务 `clipboard-x11-bridge.service` |
| `screenshot-clipboard` | 截图并写进剪贴板（niri 内置截图动作只存文件，不碰剪贴板） | niri 截图键 |
| `screenshot-sound` | 截图快门音效守护：`arm` 上膛后，剪贴板一出现图片就播快门声 | niri 自启动 + Hyprland autostart，截图键先跑 `arm` |
| `dms-wait-network` | `dms.service` 的 ExecStartPre：等网络后端抢到 D-Bus 名字再启动 DMS，最多 10s（修控制中心网络列表开机后空白） | `~/.config/systemd/user/dms.service.d/10-wait-network-backend.conf` |

## 三、截图与剪贴板

三条链路各自独立，别混：

1. **niri 截图** —— `screenshot-clipboard` 调 `niri msg action screenshot[-window|-screen]`
   先存到 `/tmp`，再用 `wl-copy` 写进剪贴板（niri 内置截图动作只落文件）。
   `Print` = 当前输出，`Alt+Print` = 当前窗口，`Ctrl+Print` = 整个屏幕。
2. **Hyprland 截图** —— 走 DMS 自带命令（`dms screenshot region|window|full`），剪贴板由 DMS 处理，
   **不经过** `screenshot-clipboard`。vellum 框选 / 长截图同理。
3. **给 X11 应用粘贴** —— Wayland 的剪贴板 X11 应用看不见，`clipboard-x11-bridge` 常驻后台，
   把 Wayland 剪贴板内容镜像成 X11 剪贴板（xclip），QQ / 微信才粘得上：
   - 300ms 轮询 + cksum 指纹去重，自身写入被回显时指纹相同会跳过，不会自循环；
   - 启动时从 `systemctl --user show-environment` 自举 `DISPLAY` / `WAYLAND_DISPLAY`
     （服务可能先于 niri 导入环境变量启动，缺变量时 wl-paste / xclip 会静默失败）；
   - X11 侧已无人持有剪贴板时自动重建，不必等下一条复制。

两条截图链路都先跑 `screenshot-sound arm` 上膛，图片进剪贴板时播放快门声。
**`arm` 必须用绝对路径调用**——合成器 spawn 的 PATH 里没有 `~/.local/bin`。

## 四、VM 测试模式（Win+Shift+D）

按 `Win+Shift+D` 进入/退出：进入后 host 快捷键全部禁用（按键透传给 VM），只留同一个键返回。

- **niri**：`Mod+Shift+D` 直接 `niri msg action load-config-file --path` 在
  `config.kdl` / `config.kdl.vmtest` 之间切换。
- **Hyprland**：`~/.config/hypr/hyprland.lua` 是指向 `hyprland.lua.normal`（正常）或
  `hyprland.lua.vmtest`（测试）的符号链接，由 `hypr-vmtest-toggle enter|leave` 原子换链后
  `hyprctl reload` 生效。**改配置请编辑 `hyprland.lua.normal`**（编辑 `hyprland.lua` 会跟随链接写到同一文件）。
- 改过正常配置后，跑一次 `niri-vmtest-gen` / `hypr-vmtest-gen` 刷新测试副本。
  两个生成脚本都带安全网：正常配置结构不符或校验（`niri validate` / `luac -p`）不通过时
  会中止并保留原测试配置，不会写出「测试模式仍加载全部快捷键」的假配置。

## 五、触摸板开关（Fn+F10）

ASUS TUF A15 的 Fn+F10 由 asus-wmi 驱动上报为 `KEY_TOUCHPAD_TOGGLE`（驱动内 `0x6B`），
但 niri 和 Hyprland 都没有对应的内置动作，故各自用脚本实现，绑定名都是 `XF86TouchpadToggle`。

| 会话 | 脚本 | 机制 | 状态存放 |
|---|---|---|---|
| niri | `niri-touchpad-toggle` | 改 `~/.config/niri/touchpad-state.kdl` 的 `off` 行后重载配置（`input.touchpad.off`） | 配置文件本身 |
| Hyprland | `hypr-touchpad-toggle` | `hyprctl eval` 设该设备 `enabled`，不必 reload | `~/.config/hypr/touchpad-state.lua` |

- 两者都是 libinput 层面的挂起（`send-events=disabled`），与 GNOME / KDE 同机制。
- 两个脚本会互相同步状态文件，所以在任一会话切换，另一会话重启后保持一致。
- 都支持 `on` / `off` / `status` 子命令，切换时有桌面通知。
- Hyprland 侧设备名写死在脚本里（`asuf1204:00-2808:0202-touchpad`），可用
  `HYPR_TOUCHPAD_DEVICE` 覆盖；niri 侧只支持 `touchpad` 这一整类设备（niri 尚无按设备配置）。

## 六、依赖的外部命令

| 命令 | 谁在用 |
|---|---|
| `fuzzel` | gsudo / fuzzel-askpass 的密码框 |
| `kitty` + `fzf` | `*-keys` 速查面板、`*-quit` 确认菜单 |
| `niri` / `hyprctl` | 与合成器交互（截图、重载配置、改设备） |
| `wl-copy` / `wl-paste` | Wayland 剪贴板（xclip 见下） |
| `xclip` | X11 剪贴板（clipboard-x11-bridge） |
| `notify-send` | 桌面通知（libnotify） |
| `pw-play` | 快门音效播放 |
| `python3` | `*-vmtest-gen` 生成配置、`*-touchpad-toggle` 改状态文件 |
| `jq` | `niri-quit` / `hypr-quit` 读配置 |
| `luac` | `hypr-vmtest-gen` 校验生成的 Lua |
| `cksum`（coreutils） | clipboard-x11-bridge 的剪贴板指纹去重 |
