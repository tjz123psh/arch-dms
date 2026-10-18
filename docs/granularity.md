# VM vs 物理机 安装颗粒度（代码事实）

两机型走**同一条 8 步流水线**（`01-system` → `08-settings`），差异只来自两处：
步骤内的 `MACHINE_TYPE` 判断，以及 `lib/common.sh` 的 `module_selected()` 对清单行的过滤。
清单行数随增改漂移，以 `manifests/` 文件本身为准。

| 颗粒度点 | 虚拟机（`-t vm`） | 物理机（`-t physical`） |
|---|---|---|
| 步骤流水线 | 8 步同构；`03-drivers` 自跳过 | 8 步同构；`03-drivers` 真实安装 |
| 包过滤（`module_selected()`） | `virtualization-vmware-guest` 仅 vm（open-vm-tools 等） | `virtualization-vmware-host` 仅 physical（vmware-workstation） |
| 硬件包 | 排除 `graphics-*` / `hardware-tools` / `asus-hardware` 的配置 | 配置照常部署（驱动在 03 步装） |
| 桌面包 | `wm-niri`（`-d niri/both`）、`wm-hyprland`（仅 `-d both`） | 同左 |
| AUR 目标 | 12 个（不含 vmware-workstation） | 13 个（含 vmware-workstation） |
| 配置部署（06） | scope `physical-v1` 共用；`asus-hardware` 行跳过 | 全量部署 |
| 服务（07） | 共享服务集 + `vmtoolsd`（必需）+ `vmware-vmblock-fuse`（可选） | 共享服务集 + `vmware-networks` / `vmware-usbarbitrator`；`supergfxd` 归 03 |
| 设置（08） | VMware guest 写 `LIBGL_ALWAYS_SOFTWARE=1`（Hyprland 无法导入 vmwgfx dma-buf） | 不写该变量；录屏走 VAAPI |

- `-d niri` 装 Niri；`-d both` 另加 Hyprland；`-d none` 跳过所有 `wm-*` 行。
- 模块过滤规则只有一处实现（`module_selected()`），改它等于同时改 02 与 06 的行为，
  属于红线改动，必须一次性 VM 完整重装验证。
- 物理机专属效果的最终确认仍需在真实 ASUS 主机上跑一次，VM 复验不能替代硬件验收。
