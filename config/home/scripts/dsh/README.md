# `~/scripts/dsh` —— dsh 运维脚本目录（桌面版时代）

> **这是 dsh 运维脚本的唯一目录。** 不要再翻 `~/Projects`、`~/.dsh` 或历史会话找脚本。
> 想在别处写等价逻辑前，先确认这里没有现成的。
> 本目录被两个技能登记为权威清单：`dsh-upgrade`（本体版本管理）与
> `dsh-plugin-management`（插件域）。**增删脚本时两张表都要同步改。**
>
> **2026-09-26 起本目录只服务官方桌面版**（AUR `deepseek-harness-desktop`，Electron，
> 自带的 dsh 运行时在 `/usr/lib/deepseek-harness-desktop/resources/app.asar` **内、只读**；
> profile 是 `~/.dsh/profiles/desktop`，端口 **19387**）。两份 CLI 安装
> （npm 全局 `~/.npm-global/lib/node_modules/@deepseek-ai/dsh` 与 archlinuxcn 的
> `deepseek-harness`）已删除，因此**本目录不再有"起服/停服/升级本体/给本体打补丁"的脚本**。

## 一句话边界（先读这条，能省半小时）

**本目录的补丁针对 profile 里的插件；桌面版本体在 `app.asar` 内，不可补。**

| 你想要的 | 实际在哪 |
|---|---|
| 升级/降级/回滚**桌面版本体** | **AUR 包管理器**（`pacman -Q deepseek-harness-desktop` 看版本；`paru -S deepseek-harness-desktop` 升级；本机 AUR helper 是 `paru`，**未装 yay**）+ `~/.dsh/backup/` 备份 |
| 起服/停服/看端口 | **桌面应用自己**（GUI 窗口即生命周期）：`ps -eo pid,args \| grep deepseek-harness-desktop`、`ss -ltnp \| grep 19387` |
| 升级/环境自检 | `~/.dsh/skills/dsh-upgrade/scripts/verify.sh`（**2026-09-26 已按桌面版改写**：锚点 `pacman -Q deepseek-harness-desktop`；实跑 24 通过 / 0 漂移 / 0 警告） |
| 插件兼容性判断 | `~/.dsh/skills/dsh-plugin-management/`（SKILL 判据表 + `references/plugin-traps.md`） |
| **本目录的 `patch-*`** | **不是检测，是"动手改代码"的补丁** —— 它们修改文件，不检查文件 |
| 想给**桌面版本体**打补丁 | **做不到**：asar 只读。只能提上游（issue/PR）或等新版 |

## 当前实际内容（分类表）

`ls` 实测（2026-09-26）：顶层 4 个脚本 + `README.md` + `retired/`（4 个死脚本 + 说明）。

### A. 核心运维（1 个）

| 脚本 | 作用 | 备注 |
|---|---|---|
| `patch-plugin-icon-renames.sh` | **profile 插件图标改名补丁 + 状态自检 + 还原**：宿主图标导出由尺寸后缀制改成字重档制（`IconXxx16/14` → `IconXxxRegular`），插件按旧名解构拿到 `undefined` ⇒ **React #130 整块 UI 崩** | 桌面版时代**唯一**的常规运维脚本：`--check` / 无参应用 / `--revert`；幂等；自动探测 `~/.dsh/profiles/desktop/node_modules`；宿主导出表从桌面版 `app.asar` 内读取（asar 路径可用 `DSH_DESKTOP_ASAR` 覆盖）。**市场/插件页更新插件会冲掉补丁，冲掉就重跑** |

**为什么它被归到"核心运维"而不是"技术债"**：桌面版时代它承担的是
"插件被市场更新后 UI 崩了怎么办"这个**常规运维动作**，不是一次性债务清理。
分类只是标签，别因此以为它可删。

### B. 补丁 = 技术债（**当前为 0 个**；历史 2 个）

本目录现在**没有**其它补丁脚本：在用的插件只剩 `dshmarket` 一个，而它自 1.65.3 起
**上游已自带图标兼容层**（`ICON_ALIASES`+`pickIcon`）⇒ A 类那支的定位已从"必需"变为**防回归闸**。两个历史补丁的去向：

| 曾经的脚本 | 改的是谁 | 现状 |
|---|---|---|
| `patch-upstream-client-modules-speedup.sh` | **dsh 自己的依赖树**（`dsh-client-modules`，启动提速 ~2.3s） | **退休**：补丁目标在 `app.asar` 内不可写；正文见 `retired/README.md` 第 4 节 |
| ~~`patch-better-sidebar-turntail-fix.sh`~~ | 第三方插件 `dsh-better-sidebar` | 2026-09-24 **随插件卸载删除**（源码归档在 `~/.dsh/backup/misc/removed-better-sidebar-patches-20260924.tar.gz`） |

**技术债的共同点（对 A 类同样成立）**：插件升级/重装/市场更新都走一轮完整 pnpm install，
pnpm 从内容寻址仓库重新硬链 `node_modules` ⇒ **补丁被冲掉**。所以：

- 桌面版**没有**"起服前自动补"的钩子了（旧的 `dsh-web.sh` 已退休）⇒ **更新插件后手工重跑**：
  `bash ~/scripts/dsh/patch-plugin-icon-renames.sh --check`，报"待改"就无参跑一次。
- **判据**：`--check` 应报"已经是修好的状态"。**但别只信它**——见下方"验证纪律"。

### C. 会话数据手术（3 个 `.mjs`）—— 应急工具，不进启动链路

| 脚本 | 用途 |
|---|---|
| `dsh-session-repair.mjs` | 把"首帧包含整个会话"的会话日志无损重排为标准布局 |
| `dsh-session-migrate.mjs` | 会话日志里 `agentPreset` 预设 id 迁移（旧值→新值） |
| `dsh-session-expand-ranges.mjs` | 把 `sourceEventSeqs` 的区间表示 `[start,end]` 展开为稠密列表 |

平时不跑，出事才用。用法见各自文件头注释与 `dsh-upgrade/references/session-data.md`。

**三个脚本都带"宿主在跑就拒绝"守卫**（2026-09-26 改造）：扫描 `/proc`，只要发现
`cmdline` 含 `deepseek-harness-desktop`（桌面版宿主，**它会写这些会话**）就 `exit 3` 并打印：

```
拒绝执行：检测到 DeepSeek Harness 桌面版正在运行 (pid N)。先退出桌面应用（它会写这些会话），或确认风险后加 --force。
```

确认风险要硬跑就加 `--force`。**旧判据（`cmdline` 含 `@deepseek-ai/dsh` 且含 `web`）在桌面版时代
恒不触发 = 守卫静默失灵**，所以必须改；`exit 3` 与 `--force` 语义保持不变。

### D. `retired/`（4 个死脚本 + `README.md`）

2026-09-26 一次性退休，**逐条理由与被什么替代见 `retired/README.md`**：

| 脚本 | 一句话退休理由 |
|---|---|
| `dsh-web.sh` | 起 `~/.npm-global/bin/dsh web`（3080）——CLI 已删、桌面版自带 web server（19387） |
| `dsh-web-watchdog.sh` | 守"关页面自动停 3080 服务"——桌面版退出即收进程，无此类孤儿服务 |
| `upgrade-dsh.sh` | npm 换装式升级器——桌面版本体是 AUR 包，且 `app.asar` 不可换装/不可补 |
| `patch-upstream-client-modules-speedup.sh` | 给 npm 树里的 `dsh-client-modules` 提速——树已删，asar 不可写 |

**纪律**：退休脚本不要再执行、也不要为了"跑通"给它们补路径；外部技能文档里把
`~/scripts/dsh/dsh-web.sh` / `upgrade-dsh.sh` 当"现成实现"的引用**已过期**。

## 验证纪律（踩过的坑，务必遵守）

1. **补丁脚本报"已修好"时，换第二种方法证伪一次。** 2026-09-23 实测事故：
   `patch-plugin-icon-renames.sh` 当时只认成员访问写法 `primitives.IconFoo16`，而 1.58 起
   打包器改成**解构后裸用** `IconFoo16` ⇒ 一处都匹配不到 ⇒ 静默报"已经是修好的状态"，
   而装机文件与上游 tarball **md5 逐字节相同**、含 138 处旧名。现已修（前缀可选 + 独立复核）；
   **最省事的证伪办法**是用第二种算法数残留（脚本内已内置）。
2. **改完必须过 `node --check` 语法闸。** 上述修复过程中，替换函数一度无条件补回前缀，
   把裸用法写成 `const { primitives.IconFooRegular } = …` ⇒ 语法错误——**是脚本自带的
   语法闸拦下并整体回滚的**。
3. **`.sh` 过 `bash -n`、`.mjs` 过 `node --check`** 是每次改动的底线。
4. **写 Bash 时注意两处易错**：条件式 `[[ … == 模式 ]]` 里的字面管道必须写 `\|`；
   `node -e '…'` 里的脚本用**单引号**包住（本次改造实测：漏了 `\|` 会被 `bash -n` 当场拦下）。
5. **动会话数据前先退出桌面应用**（守卫已强制；`--force` 只给"确认过风险"的人用）。
6. **备份只放 `~/.dsh/backup/`**；本目录脚本不留运行期状态文件
   （旧 watchdog 的 `~/.dsh/watchdog.log` / `keepalive` 已随退休消失）。

## 新增脚本时的约定

- `.sh` 必须过 `bash -n`；`.mjs` 必须过 `node --check`
- 补丁脚本统一支持 `--check` / `--revert`，并留"上游原样"备份（后缀见脚本内 `BACKUP_SUFFIX`）
- **补丁要能定位自己的目标**：桌面版没有本机 `dsh` CLI 可推导 ⇒ 一律走
  "环境变量覆盖 → 桌面版 profile / asar 自动探测 → 回退旧形态"，并且**打印实际用的是哪一个**
- **补丁要带等价性/存在性校验**：改名这类操作必须先证明目标符号在宿主导出表里真实存在
  （`patch-plugin-icon-renames.sh` 即是样板）
- **本 README 的分类表 + 两个技能的资产表都要补**（`dsh-upgrade` 的"本机资产速查"与
  `dsh-plugin-management` 的"本机脚本资产"；**2026-09-26 已同步：两处均为"顶层 4 个 + `retired/` 4 个"**）

## 遗留问题 / 待用户决策

> **2026-09-26 晚订正**：下面第 1/2/4 条在写下的当天就已被办结（本条原写"待改"），逐条复核结论如下。

1. **（已办结）两个技能文档与 `verify.sh` 均已改为桌面版口径**：`verify.sh` 六节全是 AUR 锚点
   （`EXPECTED_PKG=deepseek-harness-desktop`、`EXPECTED_VER=0.1.7rc.2-1`、顶层 4 个、`retired/` 4 个），
   实跑 **24 通过 / 0 漂移 / 0 警告**；`dsh-plugin-management` 的"本机脚本资产"与 `dsh-upgrade` 的
   "本机资产速查"都已无 `dsh-web.sh --stop` / `upgrade-dsh.sh --probe` 推荐，均为"顶层 4 个 + `retired/`"。
2. **（已办结）旧 `~/.dsh/profiles/web` 已不存在**：`ls ~/.dsh/profiles` 只有 `desktop` 与 `node_modules`，
   web 那份已移入 `~/.dsh/backup/web-era/profiles-web`。
3. **（保留）桌面版没有"补丁自动补齐"钩子**：市场每次更新插件都可能冲掉图标补丁。可选方案
   （需用户决策）：① 记住"更新后跑一次 `--check`"（当前做法，零依赖）；
   ② 给桌面版做一个插件侧补丁钩子（改动大、需上游支持）。
4. **（已办结）悬空软链 0 条**：`find ~/.dsh/profiles/node_modules -maxdepth 3 -xtype l` 实测 **0 条**；
   残留 2 条**有效**软链（`typescript`、`@deepseek-ai/dsh-agent-spine-demo`，目标都在
   `~/Projects/deepseek-harness`）—— 清理该目录时**别误删**。
