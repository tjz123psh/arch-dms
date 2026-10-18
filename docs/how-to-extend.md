# 如何增改（维护指南）

仓库是**数据驱动**的：安装器不写死清单，而是读 `manifests/` 下的表格。增改 = 加一行数据
（+ 对应文件），通常不需要改 `install.sh` 或 `steps/`。

| 想改什么 | 动哪里 |
|---|---|
| 加/删官方包 | `manifests/workstation-packages.tsv` |
| 加/删 AUR 包 | `manifests/workstation-packages.tsv` 一行（在线 paru） |
| 加/改个人配置 | `config/` + `manifests/config-mappings.tsv` |
| 加/改服务 | `steps/07-services.sh` |
| 加/改系统设置 | `steps/08-settings.sh` |
| 加/改 `~/scripts` | 本机 `~/scripts` + `./sync-scripts.sh --apply` |

## 一、加一个官方包

在 `manifests/workstation-packages.tsv` 追加一行（Tab 分隔，9 列）：

```
包名	pacman	extra	pacman	<module>	package-only	install	current-explicit	一句话用途
```

- `module` 用现有分类（`cli-tools` / `desktop-shared` / `audio` / `fonts` …）；
  没有合适的就新建一个，`lib/common.sh` 的 `module_selected()` 不认识的名字默认全装。
- 驱动类包用 `graphics-amd` / `graphics-nvidia` / `hardware-tools` / `asus-hardware`
  模块：02 步会跳过这些模块，`steps/03-drivers.sh` 按机型安装它们。
- 行顺序是追加式的，不要求字母序；已有行的列不要改含义。
- 该文件头部的注释里写着当前行数，增删行后顺手更新。

## 二、加一个 AUR 包

在 `manifests/workstation-packages.tsv` 加一行（Tab 分隔，9 列）：

```
包名	aur	aur	aur-build	<module>	package-only	install	current-explicit	一句话用途
```

- AUR 走**在线** `paru` 构建（`steps/05-aur.sh`），不需要本地 recipe。
- 只有 `paru` 自身保留 `third_party/aur/paru/` 作为 archlinuxcn 不可用时的兜底。

## 三、加一条配置映射

1. 文件放进 `config/home/...`（部署到目标用户 HOME）或 `config/etc/...`
   （`/etc` 下，06 步直装、不走映射）。
2. `manifests/config-mappings.tsv` 加一行（Tab 分隔，5 列）：

```
physical-v1	<module>	config/home/.config/xxx	.config/xxx	644
```

- mode：普通文件 `644`，可执行 `755`，含敏感内容 `600`。
- 新目录没有可继承的 module 时，用 `./sync-config-mappings.sh --module <module>`
  生成行，再人工复核。
- **凭据绝不入库**：API key / token / 密码只写 `{file:...}` 或 `{env:...}` 引用。

## 四、验证

- 任何提交前：`./dev-check.sh`（`bash -n` + 可执行位 + `shellcheck` +
  `install.sh --help`）。
- 只改数据（清单 / 配置）：dev-check 通过 + 人工复核 diff 即可。
- **红线改动**（安装主流程、manifests schema、`DESKTOP_ENV` 过滤）：在一台一次性
  虚拟机（或恢复前的宿主快照）里完整跑 `./install.sh -d niri`，8 步全过再提交；
  VM 里驱动只是安装、不生效，安装流程可以完整验收。
- 真实 GPU / ASUS 效果（supergfxd 切换、渲染）仍需真机确认，改完要说明。
