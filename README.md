# arch-dms

本人 ASUS AMD + NVIDIA 工作站的 Arch Linux 恢复工具。重装 Arch、手工做完基础安装
（分区 / GRUB / 首次启动 / 联网）之后，一条命令把整套桌面装回来：软件包、驱动、
桌面环境、AUR、个人配置与系统服务。物理机与虚拟机（VMware guest）走同一条流水线，
只在驱动步骤与模块过滤上不同。

## 基础安装前置（手工，不在本仓库范围）

下面 12 个包是恢复前提（清单里标为 `manual-precondition`，安装器不安装它们）：

`base bash btrfs-progs coreutils gawk grub linux-lts linux-zen mkinitcpio networkmanager sed sudo`

- `linux-zen`（日常内核）与 `linux-lts`（回退内核）并存；内核、initramfs 与 GRUB 由手工完成：
  `pacman -S linux-zen linux-lts && grub-mkconfig -o /boot/grub/grub.cfg`
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

两个交互选择（也可用 `-t physical|vm`、`-d niri|none` 免交互指定）：

- **机器类型**：`physical`（ASUS 工作站，装驱动）或 `vm`（VMware guest，跳过物理驱动）
- **桌面**：`niri`（Niri + Noctalia + nwg-hello，默认）/ `none`（只装包和配置）

中断后直接重跑 `./install.sh`：完成的步骤记在 `.install-progress`，从断点继续；
机器/桌面选择变了会认出来并从头开始；删掉该文件等于强制全新安装。

**AUR 只有在线模式**：第 05 步用 `paru` 从 AUR 现场构建最新版。

## 步骤

| 步骤 | 内容 |
|---|---|
| `01-system` | 镜像源、`pacman -Syu`、base-devel / git / python / curl |
| `02-packages` | 按清单装官方包（含 archlinuxcn） |
| `03-drivers` | 物理机驱动：AMD / NVIDIA、ASUS、硬件工具（虚拟机跳过） |
| `04-desktop` | Niri 与 portal 等桌面包（Noctalia 由清单安装） |
| `05-aur` | `paru` 在线安装清单里的 AUR 包 |
| `06-config` | 按 `manifests/config-mappings.tsv` 部署 `config/` |
| `07-services` | greetd + nwg-hello、系统服务、timer 与用户单元 |
| `08-settings` | locale / 时区 / zram / snapper 等系统设置 |

## 增改

- 官方包：`manifests/workstation-packages.tsv` 加一行
- 个人配置：`config/` 放文件 + `manifests/config-mappings.tsv` 加一行
  （新目录用 `./sync-config-mappings.sh` 自动补行）
- AUR：`third_party/aur/<包名>/` 放审阅过的 recipe 与 REVIEW，清单登记包行
- 提交前跑 `./dev-check.sh`（bash -n + 可执行位 + shellcheck + `--help`）
- 详细套路、验证纪律与红线见 [docs/how-to-extend.md](docs/how-to-extend.md)

## 注意

- **目标用户名为 `pang`**：`config/` 里多个文件硬编码 `/home/pang`（niri 键位、
  fish 路径、systemd user 单元、fuzzel include 等），安装器不改写。换名安装不会报错，
  但得到的是半可用桌面；确需换名要自行 `grep -rl /home/pang ~/.config ~/.local` 修正。
- **`spring` CLI 不随仓库分发**（只有 nvim 的 Spring Boot 向导用到）。
- Go 写的 AUR 包走 `config/home/.config/go/env` 里的 `GOPROXY`
  （`goproxy.cn`）；第 05 步也读这个文件，换代理只改这一处。
- 桌面验证可用后，可选跑 `./cleanup-after-install.sh` 清理 pacman / cargo / go 构建缓存
  （先列清单再确认，删除不可恢复）。
