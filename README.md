# arch-dms

本人 ASUS AMD + NVIDIA 工作站的 Arch Linux 恢复工具。重装 Arch、手工做完基础安装
（分区 / GRUB / 首次启动 / 联网）之后，一条命令把整套桌面装回来：软件包、驱动、
桌面环境、AUR、个人配置与系统服务。仓库只面向这台物理机（ASUS AMD + NVIDIA），
不再维护虚拟机分支。

## 基础安装前置（手工，不在本仓库范围）

下面 14 个包是恢复前提（清单里标为 `manual-precondition`，安装器不安装它们）：

`base bash btrfs-progs coreutils gawk grub linux-lts linux-lts-headers linux-zen linux-zen-headers mkinitcpio networkmanager sed sudo`

- archinstall 里同时选中 `linux-zen`（日常）和 `linux-lts`（回退），以及**各自的 headers**
  （`linux-zen-headers`、`linux-lts-headers`）；内核、initramfs 与 GRUB 由手工完成，
  例如补装：`pacman -S linux-zen linux-lts linux-zen-headers linux-lts-headers && grub-mkconfig -o /boot/grub/grub.cfg`
- 分区、GRUB 安装、内核 / initramfs 生成、用户与密码、首次联网全部手工完成，
  安装器不代劳。

## 安装

有网络时直接克隆：

```bash
git clone https://github.com/tjz123psh/arch-dms.git
cd arch-dms && ./install.sh
```

或在 base 系统上让 root 引导（自动克隆到 `/opt/arch-dms` 再执行 install.sh）：

```bash
sudo bash strap.sh
```

一个交互选择（也可用 `-d niri|none` 免交互指定）：

- **桌面**：`niri`（Niri + Noctalia + nwg-hello，默认）/ `none`（只装包和配置）

中断后直接重跑 `./install.sh`：完成的步骤记在 `.install-progress`，从断点继续；
桌面选择变了会认出来并从头开始；删掉该文件等于强制全新安装。

**AUR 只有在线模式**：第 05 步用 `paru` 从 AUR 现场构建最新版。

## 验收

完整安装可以在一台一次性虚拟机里验收：`./install.sh -d niri` 装的是同一套物理机包集，
驱动只是安装、不依赖真实硬件；`supergfxd` 等硬件服务起不来只告警，不会中断安装。
真实 GPU / ASUS 硬件效果仍以真机为准。

## 步骤

| 步骤 | 内容 |
|---|---|
| `01-system` | 镜像源、`pacman -Syu`、base-devel / git / python / curl |
| `02-packages` | 按清单装官方包（含 archlinuxcn） |
| `03-drivers` | 驱动：AMD / NVIDIA、ASUS、硬件工具 |
| `04-desktop` | Niri 与 portal 等桌面包（Noctalia 由清单安装） |
| `05-aur` | `paru` 在线安装清单里的 AUR 包 |
| `06-config` | 按 `manifests/config-mappings.tsv` 部署 `config/` |
| `07-services` | greetd + nwg-hello、系统服务、timer 与用户单元 |
| `08-settings` | locale / 时区 / zram / snapper 等系统设置 |

## 增改

- 官方包：`manifests/workstation-packages.tsv` 加一行
- 个人配置：`config/` 放文件 + `manifests/config-mappings.tsv` 加一行
  （新目录用 `./sync-config-mappings.sh` 自动补行）
- AUR：在 `manifests/workstation-packages.tsv` 加一行即可（在线 `paru` 构建；只有 `paru` 自身保留 `third_party/aur/paru` 兜底 recipe）
- 提交前跑 `./dev-check.sh`（bash -n + 可执行位 + shellcheck + `--help`）
- 详细套路、验证纪律与红线见 [docs/how-to-extend.md](docs/how-to-extend.md)

## 注意

- **目标用户名为 `pang`**：`config/` 里多个文件硬编码 `/home/pang`（niri 键位、
  fish 路径、systemd user 单元、fuzzel include 等），安装器不改写。换名安装不会报错，
  但得到的是半可用桌面；确需换名要自行 `grep -rl /home/pang ~/.config ~/.local` 修正。
- **文件管理器是 Nautilus**：右键增强扩展 `rice-menu.py`（`nautilus-python` + `python-gobject`）
  和 dconf 偏好随安装恢复；标签数据库 `meta.db` 属运行时数据，不入库。
- **`~/Templates` 新建文件模板**：全部收在 `config/home/Templates/`，随 `06-config` 部署；
  以后加模板跑一次 `./sync-config-mappings.sh config/home/Templates` 即可。
- **yazi**：配置在 `config/home/.config/yazi/`。`;` / `:` 的 `shell` 动作执行的是**登录 shell**
  （安装器设为 fish）；`theme.toml` 与 `flavors/noctalia.yazi/` 由 **Noctalia** 生成，
  Noctalia 重渲染主题时可能覆盖这两个文件。
- **涉及 shell 的配置**：nvim 的 `:!` 与 Java 构建固定走 **bash**（不是登录 shell fish）。
- **不纳入的敏感/大体积配置**：`~/.config/dbx/secret.key`（密钥）、transmission（含 rpc 密码哈希）、
  VS Code（420M 运行数据）、obsidian（68M）、rclone/opencode（凭据/隐私）。
- **`spring` CLI 不随仓库分发**（只有 nvim 的 Spring Boot 向导用到）。
- Go 写的 AUR 包走 `config/home/.config/go/env` 里的 `GOPROXY`
  （`goproxy.cn`）；第 05 步也读这个文件，换代理只改这一处。
- 桌面验证可用后，可选跑 `./cleanup-after-install.sh` 清理 pacman / cargo / go 构建缓存
  （先列清单再确认，删除不可恢复）。
