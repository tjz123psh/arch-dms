# arch-dms

Arch Linux 恢复工具：手工完成基础安装后，一条命令恢复 **DMS（DankMaterialShell）**
桌面（Niri）、软件包、AUR、个人配置与系统服务。
只面向这台 ASUS AMD + NVIDIA 工作站。**本仓库只维护 DMS 桌面。**

## 前置（手工，安装器不安装）

14 个包：

`base bash btrfs-progs coreutils gawk grub linux-lts linux-lts-headers linux-zen linux-zen-headers mkinitcpio networkmanager sed sudo`

archinstall 里选 `linux-zen` + `linux-lts` 和各自的 headers；分区、内核/initramfs、
GRUB、用户与首次联网都手工完成。

## 安装

```bash
git clone https://github.com/tjz123psh/arch-dms.git
cd arch-dms && ./install.sh        # 或 sudo bash strap.sh（root，克隆到 /opt/arch-dms）
```

- 桌面：`niri`（默认，DMS on Niri）/ `none`；`-d niri|none` 可免交互。
- 中断后重跑续跑（`.install-progress`）；AUR 仅在线 `paru`。
- 所有包从滚动仓库/AUR 拉取最新版本；仓库不保存版本 pin 或本地 recipe。
- 验收可在一台一次性 VM 里跑 `./install.sh -d niri`：驱动只安装、不生效。

## 步骤

01 镜像/升级 · 02 官方包 + archlinuxcn · 03 驱动 · 04 桌面 · 05 AUR ·
06 配置 · 07 服务 · 08 系统设置。

## 增改

- 包：`manifests/workstation-packages.tsv`（AUR 也只加一行，在线 paru 构建）。
- 配置：`config/` + `manifests/config-mappings.tsv`；新文件用 `./sync-config-mappings.sh`。
- 提交前 `./dev-check.sh`；细节与红线见 [docs/how-to-extend.md](docs/how-to-extend.md)。

## 注意

- **用户名必须是 `pang`**：`config/` 多处硬编码 `/home/pang`，安装器不改写。
- **DMS 登录**：greetd 用 `dms-greeter`，用户级 `dms.service`/`dsearch.service`；
  DMS 的设置、配色与壁纸在 `config/`（壁纸图片在 `~/Pictures/wallpapers/`）。
- 配置包含 nvim、yazi、Nautilus 与 `~/Templates`，由 06 步部署。
- 凭据/大体积配置不入库（dbx 密钥、transmission、VS Code、obsidian、rclone/opencode），
  见 `manifests/excluded.tsv`。
- 装完可选 `./cleanup-after-install.sh` 清 pacman/cargo/go 缓存（先确认，删除不可恢复）。
