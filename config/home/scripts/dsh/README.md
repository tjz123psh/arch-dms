# `~/scripts/dsh` —— dsh 运维脚本目录（桌面版时代）

> **这是 dsh 运维脚本的唯一目录。** 别再翻 `~/Projects`、`~/.dsh` 或历史会话找脚本。
> 两个技能把它登记为权威清单（`dsh-upgrade` / `dsh-plugin-management`）——
> **增删脚本时，本 README 分类表、两张技能资产表、`verify.sh` 的 `EXPECTED_TOP` 三处一起改。**
>
> 桌面版事实：运行时在 `/usr/lib/deepseek-harness-desktop/resources/app.asar` 内（**只读**）；
> profile 是 `~/.dsh/profiles/desktop`；**监听端口自 0.2.1 起由系统分配**（2026-10-17 实测 38167，
> 用 `ss -ltnp | grep deepseek-harnes` 查）。CLI 两份安装已删 ⇒ 这里没有"起服/停服/升级本体/给本体打补丁"的脚本。
>
> 2026-10-15：any/astra 栈随 AnyRouter 账号封禁整体删除（只剩备份包 `~/.dsh/backup/2026-10-15-purge-anyrouter/`）。
> 2026-10-17：`retired/` 清理（备份 `~/.dsh/backup/2026-10-17-retired-removed/`）。当前 **8 个脚本**。

## 边界（先读，省半小时）

**本目录的补丁只针对 profile 里的插件；桌面版本体在 `app.asar` 内，不可补。**

| 你想做的事 | 去哪 |
|---|---|
| 升级/降级/回滚本体 | AUR：`pacman -Q deepseek-harness-desktop` / `paru -S deepseek-harness-desktop`（只有 paru，无 yay）+ `~/.dsh/backup/` |
| 起服/停服/看端口 | 桌面应用本身（GUI 窗口即生命周期） |
| 升级/环境自检 | `bash ~/.dsh/skills/dsh-upgrade/scripts/verify.sh`（2026-10-17：**25 通过 / 0 漂移 / 1 警告**） |
| 插件兼容性判断 | `~/.dsh/skills/dsh-plugin-management/`（SKILL 判据表 + `references/plugin-traps.md`） |
| 给本体打补丁 | **做不到**：asar 只读，只能提上游或等新版 |
| `patch-*` | **动手改代码**，不是检测 |
| 供应商链路 | AgentRouter 两件套（A2）；AnyRouter 已退役，脚本只在备份包 |

## 脚本清单（8 个 + 本 README）

### A1. 插件图标补丁（桌面版时代唯一常规补丁）

`patch-plugin-icon-renames.sh` —— 宿主图标导出由尺寸后缀改字重档（`IconXxx16/14` → `IconXxxRegular`），
插件按旧名解构得 `undefined` ⇒ **React #130 整块 UI 崩**。本脚本负责改名 + 自检 + 还原：
`--check` / 无参应用 / `--revert`，幂等；自动探测 `~/.dsh/profiles/desktop/node_modules`，
宿主导出表从 `app.asar` 读（`DSH_DESKTOP_ASAR` 可覆盖）。**0.2.1-rc.2 起 primitives 不再单独发包**（内联成 web shell 的 seed 模块）⇒ 脚本先读老路径 `dsh/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js`，读不到就改从 `dsh-web-frontend/dist/assets/*.js` 抽 `Icon*` 名（2026-10-17 实测 99 Regular / 99 Medium / 0 数字后缀，判据不变）。
**铁律：市场更新插件会冲掉补丁 → 重跑。**

### A2. AgentRouter 本地反代（2026-10-15 起唯一在用的反代）

**`agentrouter-proxy.mjs`** —— 代理本体（`127.0.0.1:8320` → `https://agentrouter.org`），由 systemd 拉起，不手跑。
三个必需改造：① 该站只经 Clash（`127.0.0.1:7890`）可达，DSH 进程本身没设代理；② 注入 Codex 线形头
（`originator`/`version`/`user-agent`/`session_id`/`openai-beta`），否则 WAF 回 `invalid codex request`；
③ `/v1/messages` 补 `anthropic-beta: context-1m-2025-08-07`。**故意不重试**：纯透传，DSH 自己重试，避免叠加放大。

**`install-agentrouter-proxy.sh`** —— 安装器 + 体检：

```bash
bash ~/scripts/dsh/install-agentrouter-proxy.sh             # 安装或修复
bash ~/scripts/dsh/install-agentrouter-proxy.sh --check     # 只读体检：0=一致 1=漂移/故障
bash ~/scripts/dsh/install-agentrouter-proxy.sh --dry-run   # 只说做什么
bash ~/scripts/dsh/install-agentrouter-proxy.sh --uninstall # 停用并删除单元与运行时副本
```

装到 `~/.local/bin/`（0600）、写 `~/.config/systemd/user/agentrouter-proxy.service`、
验证 active + 端口 + 经代理探 `/v1/models`。

**DSH 侧供应商分组**（在 `~/.dsh/profiles/desktop/cordis.patch.yml`，不在脚本里）——
2026-10-17 三协议实测（每模型 × 带 tools）后按"能合就合、只有协议不同才拆"重组：

| 供应商 | api / baseURL | 模型 | 为什么这样分 |
|---|---|---|---|
| `agentrouter` | `openai-responses` / `http://127.0.0.1:8320/v1` | `gpt-6-astra`、`gpt-6.1-sol`、`deepseek-v4-flash` | 三者 `/chat/completions` 均 400（上游要求走 responses），responses 200 |
| `agentrouter-anth` | `anthropic-messages` / `http://127.0.0.1:8320` | `claude-opus-5-5` | 该模型在 responses 上 **503「无可用渠道」**，只能走 Anthropic 协议 |

两者都用 `AGENTROUTER_API_KEY`。`gpt-6.1-sol` / `claude-opus-5-5` 的 contextWindow 与 maxTokens
上游未暴露，配置里按同族取值并注明"未实测"。

**口径**：安装器里的 `unit_body()` 是单元内容的唯一源；手改单元会被下次安装覆盖
（`--check` 先报出，覆盖前备份 `.bak-<时间戳>`）。

**副本**：`~/scripts/dsh/`（✅ 权威源）→ `~/.local/bin/`（运行时，安装器同步）→
`~/Projects/arch-dms/...`（灾难快照，有 GitHub 远端，提交要拍板）。

> ⚠️ 2026-10-15 实测 arch-dms 那两份是**旧版**（Codex 头 0.101.0 / Mac UA、无 `session_id` /
> `openai-beta` / `UPSTREAM` 覆盖；代码指纹 `88d749e9…` vs 线上 `bb1001be…`）。**重装以本目录为准。**

**已退役 AnyRouter 三件套**（`anyrouter-proxy.mjs` / `install-anyrouter-proxy.sh` / `astra-watcher.sh`）：
2026-10-15 随账号整号封禁（`/v1/models` 与计费端点均 `403 用户已被封禁`）连同 monitor 项目删除，
脚本只在 `~/.dsh/backup/2026-10-15-purge-anyrouter/monitor-project.tar.gz`；同批删除
`anyrouter` 供应商块、`ANYROUTER_API_KEY`、`anyrouter-proxy.service`。三条教训：
别用 0 间隔"挤信道"（最可能触发封禁）；对冲收尾别 abort 赢家自己的 controller（曾致大响应读到一半被掐）；
判连通性 **200 才算通，401 只说明链路通**。

### A3. 插件开发测试树重建

`rebuild-plugin-devhost-tree.sh [--check] [插件目录]`（默认 `dsh-web-fetch-global`）：插件的
`node_modules` 是手工拼的，`@deepseek-ai/*` 宿主副本会随本体升级过期 ⇒ 插件自检大面积
`ERR_MODULE_NOT_FOUND`，而 `npm run dsh:verify` 只报 canary 漂移、看不出已经哑了。
做法：从**运行中的 app.asar** 物化宿主层 + 补依赖闭包 + 跑 `npm run test:unit`。
`--check`：0=与运行时一致 / 1=该重建。**每次本体升级后跑一次。**

### B. 补丁 = 技术债（现状 0 个，历史 2 个）

在用的插件只剩 `dshmarket`，其 1.65.3 起上游自带图标兼容层（`ICON_ALIASES` + `pickIcon`）
⇒ A1 从"必需"降为**防回归闸**。

| 历史脚本 | 现状 |
|---|---|
| `patch-upstream-client-modules-speedup.sh` | 2026-10-17 删除（目标在 asar 内不可写；见 `3c1c32b`） |
| `patch-better-sidebar-turntail-fix.sh` | 2026-09-24 随插件卸载删除（归档 `~/.dsh/backup/misc/removed-better-sidebar-patches-20260924.tar.gz`） |

共同点：插件升级/重装走完整 pnpm install，pnpm 重新硬链 `node_modules` ⇒ **补丁被冲掉**，
更新后手工重跑 `--check`（报"待改"就无参跑一次）。

### C. 会话数据手术（3 个，应急，不进启动链路）

| 脚本 | 用途 |
|---|---|
| `dsh-session-repair.mjs` | 首帧含整个会话 → 无损重排为标准布局 |
| `dsh-session-migrate.mjs` | 会话日志里 `agentPreset` 预设 id 迁移 |
| `dsh-session-expand-ranges.mjs` | `sourceEventSeqs` 的区间表示展开为稠密列表 |

三个都带"宿主在跑就拒绝"守卫：扫 `/proc`，命中 `deepseek-harness-desktop` 即 `exit 3`；
确认风险后加 `--force`。用法见文件头与 `dsh-upgrade/references/session-data.md`。

### D. `retired/`（2026-10-17 已删除）

CLI 时代 4 个死脚本已整目录删除。原件：`~/.dsh/backup/2026-10-17-retired-removed/retired.tar.gz`
或 `git checkout 3c1c32b -- dsh/retired`。理由存档：`dsh-web.sh`（起 3080，CLI 已删）、
`dsh-web-watchdog.sh`（守孤儿服务，桌面版不必）、`upgrade-dsh.sh`（npm 换装，本体是 AUR 包）、
`patch-upstream-client-modules-speedup.sh`（目标树已删）。
文档里把它当"现成实现"的引用**都已过期**。

## 验证纪律（踩过的坑）

1. **补丁报"已修好"要换第二种方法证伪**：2026-09-23 事故 —— 只认 `primitives.IconFoo16`，
   而打包器已改成解构裸用 ⇒ 一处不中、静默报修好（现内置独立复核）。
2. **改完必须过语法闸**：`.sh` → `bash -n`，`.mjs` → `node --check`（曾拦下无条件补前缀的语法错误）。
3. **Bash 两处易错**：`[[ … == 模式 ]]` 里的字面管道写 `\|`；`node -e '…'` 用单引号包。
4. **动会话数据前先退出桌面应用**（守卫强制；`--force` 只给确认过风险的人）。
5. **备份只放 `~/.dsh/backup/`**；本目录不留运行期状态文件。
6. **"脚本改了"≠"生效了"**：反代有已装副本 + systemd 单元，改完必须跑安装器；
   判据只有一条 —— `install-agentrouter-proxy.sh --check` 退出码 0。

## 新增脚本约定

- `.sh` 过 `bash -n`；`.mjs` 过 `node --check`
- 补丁脚本支持 `--check` / `--revert` 并留上游原样备份（`BACKUP_SUFFIX`）；
  **安装器类也要支持 `--check`**（样板 `install-agentrouter-proxy.sh`）
- 补丁要能自定位目标：环境变量覆盖 → 自动探测 → 旧形态回退，并**打印实际用的是哪一个**
- 改名类补丁先证明目标符号在宿主导出表里存在
- 分类表 + 两个技能资产表 + `verify.sh` 的 `EXPECTED_TOP` 三处一起补
  （现顶层 8 个 = 6 个本体脚本 + 2 个非本体维护脚本）

## 未决

- **arch-dms 的旧副本**：要不要同步成新版并提交/推送（该仓库有 GitHub 远端）—— 等你拍板。
- `dsh-session-{expand-ranges,migrate,repair}.mjs` 有更早的未提交本地改动，与本次整理无关，未动。
