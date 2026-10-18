# arch-dms

ASUS AMD + NVIDIA 工作站的 Arch 恢复工具：手工完成基础安装后，一条命令恢复
Niri + Noctalia + nwg-hello 桌面、软件包、AUR、个人配置与系统服务。
只服务这台物理机，不维护虚拟机分支。

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

- 桌面：`niri`（默认，Niri + Noctalia + nwg-hello）或 `none`；`-d niri|none` 可免交互。
- 中断后重跑续跑（`.install-progress`）；AUR 仅在线 `paru`。
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
- **shell 相关**：壁纸/配色由 **Noctalia** 管理（`~/.local/state/noctalia/` 随配置恢复，
  换壁纸会重写）；nvim 的 `:!` 与 Java 构建走 **bash**，不是登录 shell fish。
- Nautilus 扩展、yazi、`~/Templates`、壁纸都在 `config/`，由 06 部署。
- 凭据/大体积配置不入库（dbx 密钥、transmission、VS Code、obsidian、rclone/opencode），
  见 `manifests/excluded.tsv`。
- `spring` CLI 不随仓库分发；Go 的 AUR 包用 `goproxy.cn`（`config/home/.config/go/env`）。
- 装完可选 `./cleanup-after-install.sh` 清 pacman/cargo/go 缓存（先确认，删除不可恢复）。
