# 项目级指令（AGENTS）

本文件是本工作区对 agent 的最高约束，任何会话都必须遵守，优先级高于一般操作惯例。

## 一、工作区边界

- **唯一可写范围**：`/home/pang/Projects/arch-dms/`（2026-10-03 由
  `my-arch-setup-deepseek` 改名）。编辑、复制、删除、git、构建产物、运行脚本，
  都必须先确认目标路径在本仓库之内。
- **禁止修改任何其他项目**：`/home/pang/Projects/` 下的其它仓库（my-archlinux-setup、
  各类插件、k12-gmail、MD Reader、qq-agent-bot 等）一律不动；工作区之外的路径一律不动。
- **禁止破坏宿主系统**：不卸载/降级宿主软件包，不启停宿主服务，不改内核模块
  （vmmon/vmnet/kvm 等），不改 GRUB/引导与网络，不删除或移动宿主 KVM/VMware 资产
  （domain、qcow2、XML、快照、虚拟磁盘）——它们视作用户数据。
- **凭据纪律**：不读取、不打印、不记录任何密钥/token/密码值；凭据检查只报告位置与
  存在性。`config/` 中不得出现明文凭据，API key 只以 `{file:...}` / `{env:...}` 引用。
- **工作区外 VM 操作**（启动/快照/revert/guest 安装）仅在用户明确授权、且只针对其
  指定测试 VM 时执行；不 hard stop、不改真实 VMX、不把 guest 密码写进命令行或日志。

## 二、仓库定位

- 个人专用的 Arch 恢复工具：重装 Arch 并手工完成基础安装后，一条命令恢复 ASUS 工作站
  的桌面环境。remote `origin` 为 `git@github.com:tjz123psh/arch-dms.git`（公开仓库）。
- 流程：`strap.sh`（root 克隆到 `/opt/arch-dms`）+ `install.sh`（选桌面）+
  `steps/01..08`；桌面是 Niri + Noctalia + nwg-hello，AUR 只走在线 `paru`。
- **数据资产是核心价值**：`config/`（个人配置）、`manifests/`（包/映射清单）、
  `third_party/aur/`（审阅过的 AUR recipe）。优先改数据，其次才改脚本。
- **安装器必须保持可读**：`lib/common.sh` + 8 个步骤脚本，短小直白；不引入审阅引擎、
  哈希 pin、模块分级等工程化机制。

## 三、改动规则

- 提交前必跑 `./dev-check.sh`（`bash -n` + 可执行位 + `shellcheck` +
  `install.sh --help`），任一失败即禁止提交。
- **红线改动**：改安装主流程（`install.sh` / `lib/common.sh` / 步骤顺序）、改
  `manifests` 的 schema（列含义）、改 `DESKTOP_ENV` 的模块过滤——
  必须在一个**一次性测试机**（或恢复前的宿主快照）里完整跑一遍
  （`./install.sh -d niri`）再提交，不能在正在使用的宿主上试。
- 加包 / 加配置 / 加 AUR 的固定套路见 `docs/how-to-extend.md`。
- 提交信息用 Conventional Commits（`feat:` / `fix:` / `docs:` / `refactor:` /
  `chore:`），一次提交只做一件事。
