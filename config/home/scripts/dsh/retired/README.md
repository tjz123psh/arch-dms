# `retired/` —— 已退休脚本墓地（2026-09-26）

> **这些脚本仍然可以读、可以考古，但不要在桌面版时代执行它们。**
> 保留原文是为了两件事：① 以后要复刻某个机制时有现成实现；② 复盘"为什么当时那么做"。
> 每个脚本头顶的注释都是当年的原始说明，**没有改写**——历史记录不许粉饰。

## 时代背景（为什么一次性退休四个）

2026-09-26 机器上的两份 CLI 安装被删除：

- npm 全局装 `~/.npm-global/lib/node_modules/@deepseek-ai/dsh`
- archlinuxcn 的 `deepseek-harness` 包

现在只剩**官方桌面版**（AUR `deepseek-harness-desktop`，Electron）：

| 维度 | web/CLI 时代 | 桌面版时代 |
|---|---|---|
| 进程 | `dsh web`（命令行起，端口 3080） | `deepseek-harness-desktop`（Electron，GUI 内起 web server，端口 **19387**） |
| 版本与装/卸 | `npm i -g @deepseek-ai/dsh@版本` | **AUR 包**：`pacman -Q deepseek-harness-desktop`（`0.1.7rc.2-1`）/ `paru -S deepseek-harness-desktop` |
| dsh 运行时 | 可写的 npm 安装树 | `/usr/lib/deepseek-harness-desktop/resources/app.asar` 内，**只读、不可打补丁** |
| profile | `~/.dsh/profiles/web` | `~/.dsh/profiles/desktop` |
| 插件安装 | `dsh plugin --profile web add …`（本机 CLI） | 桌面版自带 pnpm 装进 profile 的 node_modules（插件页 / 市场） |
| 会话数据归属 | `dsh web` 进程写 | 桌面版进程写 |

结论：**面向"命令行起服 / npm 装本体 / 给本体打补丁"的三个脚本全部失去作用面**，
第四个（提速补丁）连补丁目标都随 npm 树一起消失了。

---

## 1. `dsh-web.sh` —— 启动器/停服/状态（12653 字节）

**当年干什么**：起 `~/.npm-global/bin/dsh web`（端口 3080）、等就绪、开浏览器、`--stop` 停服、
`--status` 看服务与客户端连接；起服前会调两个补丁脚本自动补齐；拉起看门狗。

**为什么废**：

1. 它硬编码 `DSH_BIN="$HOME/.npm-global/bin/dsh"` —— 该文件已随 npm 全局安装一起删除，
   现在执行只会报"找不到 dsh"（或更糟：把这个目录当有效安装）。
2. 端口 3080 在桌面版时代**根本没有服务**：桌面版自己起 web server，端口 19387。
   `--stop` / `--status` 查的是一台不存在的服务。
3. 起服前"自动补齐补丁"这套编排被换掉了：桌面版不用它起服，补丁改为**市场更新插件之后手工重跑**
   （`bash ~/scripts/dsh/patch-plugin-icon-renames.sh`，见 `../README.md`）。
4. 它复用的 `patch-upstream-client-modules-speedup.sh` 已经无目标（见本文件第 4 节）。

**被什么替代**：桌面应用的**启动/退出本身**（GUI 窗口即生命周期）。
进程排查用 `ps -eo pid,args | grep deepseek-harness-desktop`；端口用 `ss -ltnp | grep 19387`。
本脚本里的"宿主寄生"注意事项（起服前用 `systemd-run --user --property=KillMode=process` 脱离
调用者 cgroup）**作为技术史料仍有价值**——它是 2026-09-15"停服连带杀死新服务"事故的修复样板。

## 2. `dsh-web-watchdog.sh` —— 关页面自动停服（5107 字节）

**当年干什么**：由 `dsh-web.sh` 派生，每 5 秒数一次"本地端口上的 ESTAB 连接"；见过客户端后
"武装"，连接持续为 0 达 `--idle-sec`（默认 120）秒就 SIGTERM 掉 `dsh web`；`~/.dsh/keepalive`
文件存在时暂停计时（省内存用）。

**为什么废**：它守候的进程是 `dsh web`（3080）。桌面版时代没有这种"没有页面还活着的服务"问题——
桌面应用退出时自己收拾进程。`~/.dsh/watchdog.log`、`~/.dsh/dsh-web-watchdog.pid`、
`~/.dsh/keepalive` 三个状态文件在 2026-09-26 检查时**均已不存在**（没有孤儿文件要清）。

**被什么替代**：无（不需要）。它的"安全设计"仍值得抄：`ss` 缺失或执行失败一律视为**未知**、
只重置计时不据此停服——任何"自动关服务"的东西都该这么写。

## 3. `upgrade-dsh.sh` —— npm 时代升级器（24627 字节）

**当年干什么**：`--probe` 把新版本装到暂存前缀 + 复制 DSH_HOME 到探测目录 + 空闲端口预启动，
不碰真实 home；`--activate` 做原子切换（停服 → 换装 → 对齐实验包 → 补齐补丁 → 起服 → 验证 →
失败回滚），**必须**用 `systemd-run --user --collect --property=KillMode=process` 脱离调用者 cgroup。
里面还维护 `EXPERIMENTAL` 实验包清单与 `LAYER_MARKERS`。

**为什么废**：

1. 它升级的是 **npm 全局安装**（`~/.npm-global/lib/node_modules/@deepseek-ai/dsh`，已删除）。
   桌面版本体是 **AUR 包**，版本与文件由 pacman 管理 —— npm 换装这条路已经不存在。
2. 桌面版本的 dsh 运行时在只读 `app.asar` 内，升级器"换装安装树 + 给依赖打补丁"的整套手法
   **对 asar 无效**（asar 不可写）。
3. 它依赖 `dsh-web.sh` 停服/起服（已退休）与本地 `dsh` CLI（已删除）。

**被什么替代**：

- 升级/降级/回滚本体：**AUR 包管理器**（`paru -S deepseek-harness-desktop` / 降级装旧版本包），
  真正的回滚手段是留旧版 AUR 包文件并用 `pacman -U` 装回。
- 备份：`~/.dsh/backup/`（用户指定的 dsh 备份唯一归属目录）。
- 升级前"隔离探测"的思想仍然正确，但在桌面版上要改成**探测一个临时 DSH_HOME + 临时 profile +
  空闲端口**，而不是探测 npm 前缀。真要复刻，请从这里抄 `--probe` 的骨架，**不要**照抄换装段。

## 4. `patch-upstream-client-modules-speedup.sh` —— 启动提速补丁（6168 字节）

**当年干什么**：给 `@deepseek-ai/dsh-client-modules` 里两个热点函数换写法
（`for (const char of value)` 按码点迭代整串、`Array.from({length:n}).join(";")` 每行建串），
2026-09-14 实测把启动到就绪从 ~8.1s 压到 ~5.9s（-2.2s / -27%），
并用"补丁前后 combo 的 `rev` 与解码字节完全一致"证明**组合产物逐字节等价**。

**为什么废**：

1. 补丁目标是 **npm 安装树里的第三方依赖**（`~/.npm-global/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-modules`）
   —— 整棵树已随 npm 全局安装删除，`--check` 连文件都找不到。
2. 桌面版的 `dsh-client-modules` 在 **`app.asar` 内**，asar 不可就地打补丁；
   若将来真要提速只能走**上游**（提 issue / PR），不能在 asar 上做就地改写。

**被什么替代**：无（等上游优化）。**教训保留**：补丁脚本必须带"等价性证明"（本脚本用的是
`rev` + 解码字节逐字节比对），否则改快了但改错了没人发现。

---

## 使用纪律

- 这四个文件**不再是任何东西的依赖**：2026-09-26 已确认 `~/scripts/dsh` 下其余脚本
  （`patch-plugin-icon-renames.sh`、`dsh-session-*.mjs`）与它们零引用。
- **不要为了"跑通"而给它们补路径**：它们退休的原因是作用面消失（进程形态、安装形态、
  补丁能力三者都变了），不是路径写错。
- 外部技能文档若仍把 `~/scripts/dsh/dsh-web.sh`、`upgrade-dsh.sh` 当"现成实现"引用，
  那处引用**已过期**；需要时改指桌面版做法，并**不要**把脚本从本目录搬回上级。
