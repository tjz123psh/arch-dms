# arch-dms

面向 ASUS AMD + NVIDIA 工作站的 Arch 恢复工具：手工装好基础系统后，一条命令恢复
DMS（DankMaterialShell）+ Niri、软件包、AUR、个人配置与系统服务。只维护 DMS 桌面。

## 前置

手工准备 14 个包：

`base bash btrfs-progs coreutils gawk grub linux-lts linux-lts-headers linux-zen linux-zen-headers mkinitcpio networkmanager sed sudo`

archinstall 选 `linux-zen` + `linux-lts` 及各自 headers；分区、GRUB、用户、首次联网手工完成。

## 安装

```bash
git clone https://github.com/tjz123psh/arch-dms.git
cd arch-dms && ./install.sh        # 或 sudo bash strap.sh（root，克隆到 /opt/arch-dms）
```

- 桌面：`niri` 或 `none`，`-d niri|none` 可免交互。
- AUR 仅在线 `paru`；中断后重跑 `.install-progress` 续跑。
- 包一律取滚动仓库/AUR 最新版本，仓库不保存版本 pin 或本地 recipe。

## 步骤

01 镜像/升级 · 02 官方包 + archlinuxcn · 03 驱动 · 04 桌面 · 05 AUR ·
06 配置 · 07 服务 · 08 系统设置。

## 增改

- 包：`manifests/workstation-packages.tsv`
- 配置：`config/` + `manifests/config-mappings.tsv`，新文件用 `./sync-config-mappings.sh`
- 提交前 `./dev-check.sh`；红线见 [docs/how-to-extend.md](docs/how-to-extend.md)

## 注意

- **用户名必须是 `pang`**：`config/` 多处硬编码 `/home/pang`，安装器不改写。
- DMS 登录用 greeter + `dms-greeter`；设置、配色、壁纸在 `config/`。
- 凭据和大体积配置不入库，清单见 `manifests/excluded.tsv`。
