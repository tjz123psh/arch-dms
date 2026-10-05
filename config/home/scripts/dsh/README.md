# `~/scripts/dsh` —— dsh 运维脚本目录（桌面版时代）

> **这是 dsh 运维脚本的唯一目录。** 不要再翻 `~/Projects`、`~/.dsh` 或历史会话找脚本。
> 想在别处写等价逻辑前，先确认这里没有现成的。
> 本目录被两个技能登记为权威清单：`dsh-upgrade`（本体版本管理）与
> `dsh-plugin-management`（插件域）。**增删脚本时两张表 + `dsh-upgrade/scripts/verify.sh`
> 的期望集合都要同步改。**
>
> **2026-09-26 起本目录只服务官方桌面版**（AUR `deepseek-harness-desktop`，Electron，
> 自带的 dsh 运行时在 `/usr/lib/deepseek-harness-desktop/resources/app.asar` **内、只读**；
> profile 是 `~/.dsh/profiles/desktop`，端口 **19387**）。两份 CLI 安装
> （npm 全局 `~/.npm-global/lib/node_modules/@deepseek-ai/dsh` 与 archlinuxcn 的
> `deepseek-harness`）已删除，因此**本目录不再有"起服/停服/升级本体/给本体打补丁"的脚本**。
>
> **2026-10-04 复理**：新增供应商链路三件套（见 A2 组）；本表原本还停在 9-26 的"顶层 4 个"，
> 已补正为**顶层 7 个 + `retired/` 4 个**。

## 一句话边界（先读这条，能省半小时）

**本目录的补丁针对 profile 里的插件；桌面版本体在 `app.asar` 内，不可补。**

| 你想要的 | 实际在哪 |
|---|---|
| 升级/降级/回滚**桌面版本体** | **AUR 包管理器**（`pacman -Q deepseek-harness-desktop` 看版本；`paru -S deepseek-harness-desktop` 升级；本机 AUR helper 是 `paru`，**未装 yay**）+ `~/.dsh/backup/` 备份 |
| 起服/停服/看端口 | **桌面应用自己**（GUI 窗口即生命周期）：`ps -eo pid,args \| grep deepseek-harness-desktop`、`ss -ltnp \| grep 19387` |
| 升级/环境自检 | `bash ~/.dsh/skills/dsh-upgrade/scripts/verify.sh`（2026-09-26 已按桌面版改写；2026-10-04 复跑 **23 通过 / 0 漂移 / 0 警告**，期望集合已补成 7 个） |
| 插件兼容性判断 | `~/.dsh/skills/dsh-plugin-management/`（SKILL 判据表 + `references/plugin-traps.md`） |
| **本目录的 `patch-*`** | **不是检测，是"动手改代码"的补丁** —— 它们修改文件，不检查文件 |
| 想给**桌面版本体**打补丁 | **做不到**：asar 只读。只能提上游（issue/PR）或等新版 |
| **供应商链路**（AnyRouter / AgentRouter 本地代理） | A2 组三个脚本（本目录）+ 恢复说明 `~/md/供应商配置/dsh-供应商链路恢复文档.md` |

## 当前实际内容（分类表）

`ls` 实测（2026-10-04）：顶层 **7 个脚本** + `README.md` + `retired/`（4 个死脚本 + 说明）。

### A. 常规运维（4 个）

#### A1. 插件图标补丁（桌面版时代**唯一**的常规补丁）

| 脚本 | 作用 | 备注 |
|---|---|---|
| `patch-plugin-icon-renames.sh` | **profile 插件图标改名补丁 + 状态自检 + 还原**：宿主图标导出由尺寸后缀制改成字重档制（`IconXxx16/14` → `IconXxxRegular`），插件按旧名解构拿到 `undefined` ⇒ **React #130 整块 UI 崩** | `--check` / 无参应用 / `--revert`；幂等；自动探测 `~/.dsh/profiles/desktop/node_modules`；宿主导出表从桌面版 `app.asar` 内读取（`DSH_DESKTOP_ASAR` 可覆盖）。**市场/插件页更新插件会冲掉补丁，冲掉就重跑** |

**为什么它在"常规运维"而不是"技术债"**：它承担的是"插件被市场更新后 UI 崩了怎么办"这个
**常规动作**，不是一次性债务清理。分类只是标签，别因此以为它可删。

#### A2. 供应商链路三件套（2026-10-04 新增，本机 `gpt-6-astra` 靠它）

| 脚本 | 作用 | 调用 |
|---|---|---|
| `anyrouter-proxy.mjs` | **AnyRouter 本地反向代理本体**（`127.0.0.1:8321` → `https://anyrouter.top`，经 Clash 出网）。干三件事：① 网络只经 Clash 可达，直连 TLS 握手就挂；② **注入 Codex 线形头**（`originator` / `version` / `OpenAI-Beta` / `session_id`），AnyRouter 的 astra 信道缺这些头直接回 `400 invalid codex request`；③ **挤信道重试 + 对冲并发**（信道常满，网关会把请求挂 ~80 秒才回 500，所以在转发层重试，对 DSH 透明） | 不直接手跑；由 systemd 用户服务拉起。装/修走下一行 |
| `install-anyrouter-proxy.sh` | 安装器 + 体检：把上一条装到 `~/.local/bin/`、写 `~/.config/systemd/user/anyrouter-proxy.service`、`enable --now`、再用 `/v1/models` 验证连通 | `bash ~/scripts/dsh/install-anyrouter-proxy.sh`（安装/修复）、`… --check`（**只体检不写文件**：副本是否最新 / 单元是否与脚本口径一致 / 服务与端口是否活着；退出码 0=全一致 1=有故障 2=单元被手工改过 3=源脚本缺失） |
| `astra-watcher.sh` | **盯"astra 什么时候能用"的守夜脚本**：每轮**先确认 Clash 节点活着**再探 astra；通了打印返回内容并 `exit 0`，盯完没通 `exit 1`。来历 = 2026-10-04 教训（盲目重试时 Clash 节点其实已经挂了，上万次尝试全打在断掉的网络上）。**它的 codex 版本号 0.153.0 与 `anyrouter-proxy.mjs` 的 `CODEX_HEADERS` 对齐——改一处要改另一处** | `bash ~/scripts/dsh/astra-watcher.sh`（默认 240 轮 × 60 秒 = 4 小时）；`CYCLES=10 INTERVAL=30 bash …` 快速试。密钥从 `$DSH_HOME/.credentials.yaml` 读，**不落盘** |

**调参与覆盖纪律（踩过，务必遵守）**：`~/.config/systemd/user/anyrouter-proxy.service`
里的 `ANYROUTER_PROXY_*` 参数是**线上有效值**，脚本 `unit_body()` 是它的**唯一源码副本**，
两边现在一致（`--check` 拿"丢掉注释后的生效指令"做指纹，注释措辞不同不算漂移）。
**只改单元不跑脚本 → 下次安装会被脚本覆盖回去**；要改就改脚本再跑一次，
或改完单元后把 `Environment` 段抄回脚本。安装器改单元前会先备份成
`anyrouter-proxy.service.bak-<时间戳>`。

**4 份副本与"只认一个源"（2026-10-04 收口）**：同一个 `anyrouter-proxy.mjs` 在本机有 4 份。
**权威源只有一个 —— 本目录**；另外三份都是派生副本，2026-10-04 已全部同步成同一版内容，
并在文件头加了"本文件是生成副本"的出处标注：

| 路径 | 角色 | 谁负责同步 |
|---|---|---|
| `~/scripts/dsh/anyrouter-proxy.mjs` | ✅ **权威源**（只改这里） | 你 |
| `~/.local/bin/anyrouter-proxy.mjs` | 运行时副本（服务实际跑的就是它） | `install-anyrouter-proxy.sh`（无参） |
| `~/md/供应商配置/dsh-provider-kit/anyrouter-proxy.mjs` | 灾难恢复快照（`~/md` 无远端，重装前要自己拷走） | 手工 `cp`（见恢复文档 §四第 2 步） |
| `~/Projects/arch-dms/config/home/.local/bin/anyrouter-proxy.mjs` | arch-dms 一键重装 payload（**这个仓库有 GitHub 远端**） | 手工 `cp` + 在 arch-dms 里提交 |

**为什么必须同步**：09-18 那版**没有** Codex 头注入与挤信道重试 ⇒ 重装后装上去也连不上 astra，
而恢复文档当时正指着它（现已改指本目录 + 安装器）。

> **2026-10-04 复理时这里抓到并修掉一个真 bug（教训存档）**：对冲逻辑收尾时写的是
> `ctls.forEach((c) => c.abort())`，把**赢家自己的控制器**也 abort 了，而赢家的响应体流还挂在
> 那个 signal 上 ⇒ 已读完首块、正文还没读完的响应会在 `read()` 抛
> `This operation was aborted`，客户端拿到 `curl: (52) Empty reply from server`。
> **只有"带真 key 的成功大响应"中招**：401 这类小响应首块即全部，恰好躲过；所以
> 表面症状像"网络问题/信道满"，实际是本地一行代码。现在改成
> `if (c !== winner.ctl) c.abort()`（源文件头部有修复记录）。
> 判定手段：`curl -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8321/v1/models -H "Authorization: Bearer $ANYROUTER_KEY"`
> —— **200 才算通，401 只能证明"链路通"**。
**判定副本是否同步**：逐字节比 → `md5sum` 应都是 `55f5d07c3d5a94e3ed32e2db9721c7f5`；
带出处标注的两份会因头注释不同而 md5 不同，**属正常**——用
`bash ~/scripts/dsh/install-anyrouter-proxy.sh --check`（比"去掉头注释后的代码指纹"）判断即可。

### B. 补丁 = 技术债（**当前为 0 个**；历史 2 个）

本目录现在**没有**其它补丁脚本：在用的插件只剩 `dshmarket` 一个，而它自 1.65.3 起
**上游已自带图标兼容层**（`ICON_ALIASES`+`pickIcon`）⇒ A1 那支的定位已从"必需"变为**防回归闸**。两个历史补丁的去向：

| 曾经的脚本 | 改的是谁 | 现状 |
|---|---|---|
| `patch-upstream-client-modules-speedup.sh` | **dsh 自己的依赖树**（`dsh-client-modules`，启动提速 ~2.3s） | **退休**：补丁目标在 `app.asar` 内不可写；正文见 `retired/README.md` 第 4 节 |
| ~~`patch-better-sidebar-turntail-fix.sh`~~ | 第三方插件 `dsh-better-sidebar` | 2026-09-24 **随插件卸载删除**（源码归档在 `~/.dsh/backup/misc/removed-better-sidebar-patches-20260924.tar.gz`） |

**技术债的共同点（对 A1 同样成立）**：插件升级/重装/市场更新都走一轮完整 pnpm install，
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
7. **"脚本改了"不等于"生效了"**（2026-10-04 新增）：A2 那套还有个**已装副本**和一份
   **systemd 单元**在别处。改完 `anyrouter-proxy.mjs` 必须跑一次安装器（或
   `--check` 确认已同步），否则线上跑的还是旧副本。判据只有一条：
   `bash ~/scripts/dsh/install-anyrouter-proxy.sh --check` 退出码 0。

## 新增脚本时的约定

- `.sh` 必须过 `bash -n`；`.mjs` 必须过 `node --check`
- 补丁脚本统一支持 `--check` / `--revert`，并留"上游原样"备份（后缀见脚本内 `BACKUP_SUFFIX`）；
  **安装器类脚本也要支持 `--check`**（只读体检 + 非零退出码报告漂移，样板见
  `install-anyrouter-proxy.sh`）
- **补丁要能定位自己的目标**：桌面版没有本机 `dsh` CLI 可推导 ⇒ 一律走
  "环境变量覆盖 → 桌面版 profile / asar 自动探测 → 回退旧形态"，并且**打印实际用的是哪一个**
- **补丁要带等价性/存在性校验**：改名这类操作必须先证明目标符号在宿主导出表里真实存在
  （`patch-plugin-icon-renames.sh` 即是样板）
- **本 README 的分类表 + 两个技能的资产表 + `verify.sh` 的 `EXPECTED_TOP` 三处都要补**
  （`dsh-upgrade` 的"本机资产速查"、`dsh-plugin-management` 的"本机脚本资产"；
  **2026-10-04 已同步：顶层 7 个 + `retired/` 4 个**）

## 遗留问题 / 待用户决策

> 2026-10-04 复理时逐条重核：1–4 条已办结（保留结论备查），5–7 条为新发现。

1. **（已办结）两个技能文档与 `verify.sh` 均已改为桌面版口径**；2026-10-04 复跑
   **23 通过 / 0 漂移 / 0 警告**（原 24 通过来自"顶层恰好 4 个"这一条，现已改成 7 个）。
2. **（已办结）旧 `~/.dsh/profiles/web` 已不存在**（移入 `~/.dsh/backup/web-era/profiles-web`）。
3. **（保留）桌面版没有"补丁自动补齐"钩子**：市场每次更新插件都可能冲掉图标补丁。
   现做法 = 记住"更新后跑一次 `--check`"（零依赖）。
4. **（已办结）悬空软链 0 条**：`~/.dsh/profiles/node_modules` 下无失效软链；
   残留 2 条**有效**软链（`typescript`、`@deepseek-ai/dsh-agent-spine-demo`，目标在
   `~/Projects/deepseek-harness`）—— 清理该目录时**别误删**。
5. **（已办结）陈旧副本收口 = "只留本目录当源"**（用户 2026-10-04 指示）：另三份派生副本
   已全部同步成新版并加"生成副本"出处标注；恢复文档已改成"anyrouter 走
   `install-anyrouter-proxy.sh`、源在本目录"。旧那份 09-18 版留档在
   `~/.dsh/backup/misc/provider-copies-before-sync-20261004/`（要考古再从那儿翻）。
6. **（待用户定）`astra-watcher.sh` 的去留**：它是为"等 astra 恢复"这个具体事件写的
   守夜脚本（盯 4 小时就退出）。现在按**常备工具**留在顶层（README A2 组）；若你觉得
   astra 不会再盯了，可以按 retired 规格退休到 `retired/`——**这是分类决定，不影响功能**。
7. **（待用户定）两个仓库的提交**：
   - `~/scripts` 是 git 仓库，本目录三个新脚本（`anyrouter-proxy.mjs` / `astra-watcher.sh` /
     `install-anyrouter-proxy.sh`）目前**未跟踪**（其余脚本都已提交）；
   - `~/Projects/arch-dms`（**有 GitHub 远端**）里那份代理副本与 systemd 单元已被本次同步改写，
     处于"已修改未提交"状态；要不要提交/推送、以及 `config-mappings.tsv` 要不要登记，
     涉及往另一个公开仓库写入，**等用户拍板**。
   本次整理**没有**动这两个仓库的 git 状态（一个文件都没 `git add`）。
