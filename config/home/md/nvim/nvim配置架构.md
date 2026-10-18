# Neovim 配置架构

这里描述当前配置；故障经过留在[排障历史](</home/pang/.agents/skills/nvim-troubleshooting/references/nvim-troubleshooting-history.md>)，不再把旧实现和当前规则混在同一张表里。使用中的基线为 Neovim 0.12.6。

## 加载顺序

[根入口](</home/pang/.config/nvim/init.lua>)依次加载 core、languages.setup()、core.lazy，最后只在 Neovide 中加载 GUI 设置。

- core 初始化通用编辑行为，不启动语言服务。
- languages 读取纯声明，注册文件类型、语言选项和全局语言入口；重实现仍按需加载。
- lazy.nvim 接管插件加载；公共 LSP/DAP/格式化/工具消费者读取语言声明，不再维护第二份语言清单。
- 修改后保存并完整重启；:R 只执行当前磁盘 Lua 文件，不清 require 缓存，也不是插件热重载。

## 目录与职责

~~~text
init.lua
lua/
├─ core/
│  ├─ init.lua               通用配置的固定初始化顺序
│  ├─ options.lua            编辑器选项、provider、shell、真彩色环境
│  ├─ lazy.lua               插件引导和加载策略
│  ├─ keymaps.lua            全局快捷键入口
│  ├─ movement.lua           J/K 移动行与选区保真
│  ├─ commands.lua           A、BufDelete、CheatSheet，以及项目命令接线
│  ├─ autocmds.lua           自动保存、直接 Ex 退出与 ZQ 的丢弃保护
│  ├─ diagnostics.lua        诊断显示、日志轮转、LspInfo/LspLog
│  ├─ cjk_punct.lua          中文标点输入与范围转换
│  ├─ projects/
│  │  ├─ init.lua            项目命令、根检测兼容、切换与树刷新
│  │  ├─ history.lua         三源历史、镜像、回填、只追加写守卫
│  │  └─ picker.lua          项目排序、显示与确认；框按屏幕比例放大
│  └─ ui/
│     ├─ init.lua            soft/pink 色板、PickerSkin、ColorScheme
│     ├─ input.lua           Snacks/Noice 共用的输入框尺寸
│     ├─ cheatsheet.lua      速查窗口绘制和生命周期
│     ├─ reference.lua       速查数据，首次打开时才加载
│     └─ neovide.lua         GUI 字体、144 Hz、缩放与不透明度持久化
├─ languages/
│  ├─ init.lua               统一声明收集、合并与冲突检查
│  ├─ README.md              声明合同和扩展规则
│  ├─ shared/                共享 LSP 动作、clangd/codelldb 等
│  ├─ c/ cpp/ go/ rust/ lua/
│  ├─ html/ css/
│  ├─ json/ yaml/ xml/ markdown/
│  └─ java/                  Java 运行、调试、模板、LSP 与 spring/ 子目录
└─ plugins/
   ├─ languages.lua          只接入语言入口明确声明的插件
   ├─ lsp/init.lua           公共 LSP 启用流程
   ├─ dap/init.lua           调试接线、单份键位、UI 和协议适配
   ├─ project.lua            项目插件偏好，委托 core.projects 安全接线
   ├─ snacks.lua             选择器、输入框、紧凑/grep 布局
   └─ 其他单文件插件          保持短小声明，不为十几行配置再建一层目录
~~~

[语言指南](</home/pang/.config/nvim/lua/languages/README.md>)列出完整字段合同。当前保留 12 种已配置语言服务的语言目录。2026-10-15 按用户要求移除 Python、Bash、Vim、JavaScript、TypeScript、Vue、Svelte 的独立入口及专属高亮/缩进声明，管理的解析器清单由 24 项减为 16 项；不卸载已安装工具和解析器。C/C++ 共用 clangd，C/C++/Rust 共用 codelldb，语言之间不直接 require。

## 维护原则

1. 小插件用 opts；必要接线才用 config。懒加载键直接在 keys 写回调，不再同时维护键壳和另一套映射。
2. 插件 require 放在回调或实际加载阶段。速查数据、项目选择器、Java 向导不因启动而提前求值。
3. 大功能按职责内聚；保留 core.projects 和 core.ui 的公开入口。不要另造全局 registry/util 框架，也不保留旧路径转发文件。
4. 新语言只改自己的目录和注册表 names。公共插件不再添加语言专属判断。
5. 源码注释说明约束和危险边界，不重复翻译 API，也不粘贴故障复盘。中文快捷键说明是功能数据，不当作注释删除。
6. 当前未提交工作也是基线。备份、快照不能只取 Git HEAD；删除旧模块前先改完引用并验证新入口。

## 必须保留的行为边界

| 范围 | 当前约定 |
|---|---|
| [保存与退出](</home/pang/.config/nvim/lua/core/autocmds.lua>) | BufLeave/FocusLost 保存当前普通文件；正常退出保存所有修改。q!/qa!/cq 与 ZQ 保留丢弃语义。原生命令解析、退出队列、WinClosed/SafeState 清理和同步保护不得换成简单 writeall。 |
| [移动行](</home/pang/.config/nvim/lua/core/movement.lua>) | J/K 支持数字前缀、普通/可视/选择模式。保留光标列和选区子模式；普通模式不重缩进，文本无缩进来源或存在 equalprg 时不调用 =。 |
| [中文标点](</home/pang/.config/nvim/lua/core/cjk_punct.lua>) | 按完整 UTF-8 字符转换；文本/Markdown 等保留全角。CJKPunctFix 默认整篇，单地址/显式范围交给原生 range="%"。粘贴与 InsertCharPre 不是同一条路径。 |
| [诊断](</home/pang/.config/nvim/lua/core/diagnostics.lua>) | 长消息按显示宽度折行，箭头行不折，最多 12 行；浮窗保留完整内容。Ctrl-C 退出插入模式仍补绘。日志级别 ERROR，超过 5MB 轮转。 |
| [项目历史](</home/pang/.config/nvim/lua/core/projects/history.lua>) | 自有只追加副本、插件文件、会话项目取并集；缺项 append 回填；上游写守卫永不截断，也不写 recent_projects。并发可能增加重复行，读取去重。 |
| [项目选择](</home/pang/.config/nvim/lua/core/projects/picker.lua>) | 最长匹配根只计算一次，用于置顶和徽标；独立 source=project-history、字段 project_dir；含空格路径走 Lua API。保留自动根检测与镜像各自的标记范围，不擅自取并集。 |
| [搜索布局](</home/pang/.config/nvim/lua/plugins/snacks.lua>) | grep 的布局独立构造；宽屏左右、窄屏上下，resize 重算。不深合并 select 的数字子节点。复制默认键表，只覆盖 Esc 一次取消。项目列表按屏幕比例放大（宽 80%、高 60%，并保证最长一行不被截断）；其它 picker 维持紧凑尺寸。 |
| [输入框](</home/pang/.config/nvim/lua/core/ui/input.lua>) | Snacks 开窗动态取宽度；Noice 的 min_width 是加载时数字，并由 cmdline_input 继承 cmdline_popup。两种边框位置可能差一行，不保证 resize 后完全相等。Snacks 输入框 Esc 先退出插入，再 Esc 取消；选择列表 Esc 一次取消。 |
| [界面](</home/pang/.config/nvim/lua/core/ui/init.lua>) | 保留 soft/pink 与切主题后重放。BufDelete 保分屏和未保存确认；状态栏保实底，文件树保偏移。Neovide 的 144 Hz、字体和不透明度文件不变。 |
| [终端](</home/pang/.config/nvim/lua/plugins/terminal.lua>) | 浮动/水平/垂直分别使用 1/2/3；从浮窗切分屏前先换焦点，退出保留输出。Java 应用/构建使用自己的项目和用途归属。 |
| [AI 面板](</home/pang/.config/nvim/lua/plugins/sidekick.lua>) | 不启用 NES 或 tmux；aa 隐藏/显示，ad 关闭直连会话，不混为同一个动作。面板是上游默认的右侧分屏；`config` 把面板 winhighlight 的目标组 `SidekickChat` 链接到 `Normal`——未定义组会退回 UI 默认背景，让面板在透明主题下变成实心块。分屏没有边框、四角是直角，圆角只能用浮窗（当前不采用）。测试不启动真实 AI 会话。 |
| [DAP](</home/pang/.config/nvim/lua/plugins/dap/init.lua>) | 空条件/日志输入不创建断点；Java 局部 F5 优先。当前锁定版 virtual-text 的 stackTrace 参数仍是旧合同，在配置层把 session,err,response 适配为 session,response，保留全栈显示；升级插件后重跑监听器测试。 |
| [工具安装](</home/pang/.config/nvim/lua/plugins/mason.lua>) | Mason 先设置 PATH，工具安装器依赖 Mason，不循环依赖；启动不刷新/安装工具。手动 MasonToolsInstall/LspInstall 仍可用。Treesitter 缺解析器自动尝试保留 6 小时节流。 |
| [插件引导](</home/pang/.config/nvim/lua/core/lazy.lua>) | 关闭启动更新检查，手动 Lazy check。残缺 lazy.nvim 目录先改名保留，克隆失败明确停止，不自动 rm 原目录。 |

## 快捷键与命令

真实绑定仍在所属模块；[速查数据](</home/pang/.config/nvim/lua/core/ui/reference.lua>)包含内置键、组合写法和说明，不作为另一套映射注册表。打开方式为 `<leader>hk` 或 `:CheatSheet`。Which-key 只改分组/中文说明，不制造不存在的入口。

- J/K 移动行，`<leader>j` 合并行，gh 查看 LSP 文档；保留原有主要快捷键。
- 通用/LSP/DAP/Java/Spring/Markdown/Neovide 菜单区分适用范围；没有可用子项的空组收起。
- [共享语言动作](</home/pang/.config/nvim/lua/languages/shared/actions.lua>)复用原生 code_action；Ra 只筛重构，ot 只筛整理导入，不按标题猜动作。Java 保留 jdtls 增强；矩形选区不冒充普通选区。
- 详细命令分别见[命令表](</home/pang/md/nvim/nvim命令.md>)与[自定义命令](</home/pang/md/nvim/nvim自定义命令.md>)。

## Java / Spring Boot（2026-10-14）

插件声明只维护偏好，实际逻辑集中在 [Java 目录](</home/pang/.config/nvim/lua/languages/java/>)；不把单文件、项目构建和 DAP 强行变成一种执行器。

- **算法**：`:JavaRun` / `<leader>Jr` 明确保存，javac 临时编译当前源码与所需辅助类，原生终端接收 stdin；产物退出即清理。有包时目录须匹配，项目依赖与项目 JDK 交给 F5/构建工具。
- **项目**：F5 每次获取当前 jdtls 的主类、JDK、module/classpath；Jd 只查询。Jt/JT 用构建工具跑当前方法/类；Jg/JG 保留 jdtls 最近测试方法/文件测试类的语义。上游 attach 会加载 DAP，不承诺“直到 F5 才加载”。
- **Spring 运行**：sr 扫主源码集的真实 main；Maven 保留标准/自定义属性，写死不同主类则拒绝；Gradle 多入口需配置 bootRun.mainClass 或改用 F5。全部启动逐个等 Started，失败/超时停止。构建/测试与各主类终端隔离，通用 1/2/3 不动。
- **生成**：Gc/Gi/Ge/Gr 使用一份模板，完整类名决定包目录；拒绝非法标识符、已有文件或已有缓冲区，不再自动改空 Java 文件。
- **向导**：[Spring 向导](</home/pang/.config/nvim/lua/languages/java/spring/wizard.lua>)保留 11 步与可搜索多选、soft/pink 卡片；直接调用[官方 Initializr](<https://start.spring.io>)，使用 curl/unzip/GNU mv，不需要 spring CLI。创建在私有暂存完成后无覆盖发布；取消、HTTP 失败、同名目标、异常 ZIP 均有出口。

JDTLS 以已安装 Java 21 启动，项目可选 JavaSE-21 / JavaSE-1.8；Lombok 优先使用自备 jar，缺失时使用 Mason jdtls 随附 jar。按 buffer 关闭 Java/Spring 语义 token，保留现有 Treesitter 颜色。修改配置后保存并重启 Neovim，`:R` 不是完整热重载。

Gradle 的安装到本地仓库使用 publishToMavenLocal，需要项目启用 maven-publish。没有 wrapper、PATH 或缓存中的构建工具时给出明确提示，不安装任何工具。


## 验证与隔离

基本回归：[自动保存](</home/pang/.config/nvim/tests/autosave.lua>)、[编辑与懒加载动作](</home/pang/.config/nvim/tests/core_workflows.lua>)、[历史和项目选择](</home/pang/.config/nvim/tests/projects.lua>)、[菜单范围](</home/pang/.config/nvim/tests/whichkey_scopes.lua>)、[安装策略](</home/pang/.config/nvim/tests/install_policy.lua>)。

运行层回归：[真实通用 UI](</home/pang/.config/nvim/tests/core_ui_smoke.py>)、[Java](</home/pang/.config/nvim/tests/java_runtime_smoke.lua>)、[Spring/JUnit](</home/pang/.config/nvim/tests/spring_runtime_smoke.lua>)、[C/C++/Rust/Go DAP](</home/pang/.config/nvim/tests/dap_languages_smoke.lua>)、[Lua/Markdown](</home/pang/.config/nvim/tests/editor_languages_smoke.lua>)。行内变量协议单独由[监听器测试](</home/pang/.config/nvim/tests/dap_listener.lua>)覆盖。

[配置快照](</home/pang/.config/nvim/tests/config_snapshot.lua>)比较实际选项、全模式键位、命令、插件与皮肤。函数地址、自动生成的不相交 Noice 路由顺序、启动期间动态 runtimepath 不能直接当行为差异；仍要核对真正的选项变更和实际功能。退出码 0 也必须检查 stderr，不能漏掉异步 Lua 错误。

所有完整配置测试使用新临时目录和隔离 XDG；仅复用已安装插件/工具，不在用户工程做测试，不升级依赖。例：

```bash
T=$(mktemp -d /tmp/nvim-java-check.XXXXXX)
export XDG_STATE_HOME="$T/state" XDG_DATA_HOME="$T/data" XDG_CACHE_HOME="$T/cache"
mkdir -p "$T/data/nvim/site" "$T/state/nvim" "$T/cache"
ln -s "$HOME/.local/share/nvim/lazy" "$T/data/nvim/lazy"
ln -s "$HOME/.local/share/nvim/mason" "$T/data/nvim/mason"
ln -s "$HOME/.local/share/nvim/site/parser" "$T/data/nvim/site/parser"
if test -d "$HOME/.local/share/nvim/site/queries"; then
  ln -s "$HOME/.local/share/nvim/site/queries" "$T/data/nvim/site/queries"
fi
date +%s > "$T/state/nvim/treesitter-install-stamp" # 测试不触发解析器下载
nvim -u NONE -i NONE -n --headless -l tests/java_workflows.lua
NVIM_JAVA_TEST_TMP="$T/config" nvim -u NONE -i NONE -n --headless -l tests/java_config.lua
NVIM_JAVA_TEST_TMP="$T/files" nvim -u NONE -i NONE -n --headless -l tests/java_files_smoke.lua
NVIM_JAVA_TEST_TMP="$T/terminals" nvim -u NONE -i NONE -n --headless -l tests/java_terminal_smoke.lua
NVIM_JAVA_TEST_TMP="$T/jdtls" nvim -u NONE -i NONE -n --headless -l tests/java_jdtls_smoke.lua
nvim -u NONE -i NONE -n --headless -l tests/spring_wizard.lua
NVIM_JAVA_TEST_TMP="$T/java" nvim -i NONE -n --headless '+luafile tests/java_runtime_smoke.lua'
NVIM_JAVA_TEST_TMP="$T/spring" nvim -i NONE -n --headless '+luafile tests/spring_runtime_smoke.lua'
NVIM_JAVA_TEST_TMP="$T/ui" python3 tests/java_ui_smoke.py
nvim -u NONE -i NONE -n --headless -l tests/language_actions.lua
nvim -u NONE -i NONE -n --headless -l tests/whichkey_scopes.lua
```

项目测试额外设置 NVIM_CORE_TEST_TMP="$T/projects"；通用 UI 使用 NVIM_JAVA_TEST_TMP="$T/core-ui"，该目录必须尚不存在。只终止本轮创建的进程和客户端，不按名称通杀。

上一轮整体验收（2026-10-14）通过：31 个保存/退出场景、50 项编辑/懒加载动作、25 项历史/项目、56 项目录/归属、116 项菜单检查；78 项真实通用 UI、23 项 Java、30 项 Spring/JUnit、28 项跨语言调试和 8 项 Lua/Markdown 检查。语言声明、向导、共享动作与禁止启动安装的既有回归也通过。Java/Spring 选择界面另通过 26 项真实按键检查；虚拟文本的错误/空响应和全栈成功路径另有确定性协议测试。

非语言运行 Lua 从 3727 减到 3169 行（约15%），整行注释559→61；保留必要的安全分支。该轮语言实现保持不变，插件没有增删升级；2026-10-15 后的保留名单见上方目录说明。12轮交错启动各剔除前2次，预热中位52.92→53.61ms，本次速度基本持平，不将删注释宣称为提速。健康检查未发现 LSP/Spring/弃用 API 问题，lazy 的空隔离包目录提示已核实。

## 文档与恢复

本次语言清理前的[完整备份](</home/pang/.local/state/nvim/language-trim-20261015-130052.tar.gz>)保留了被移除的七个入口和原注册表；需要恢复时仅提取相关文件，避免覆盖其它未提交修改。

[整体重构备份](</home/pang/.local/state/nvim/config-refactor-20261014-223932.tar.gz>)包含当时全部配置、未跟踪语言文件、用户文档与维护参考；按需恢复，不覆盖其它未提交改动。

修改功能后同步现有四份文档：[架构](</home/pang/md/nvim/nvim配置架构.md>)、[插件介绍](</home/pang/md/nvim/nvim插件介绍.md>)、[命令](</home/pang/md/nvim/nvim命令.md>)、[自定义命令](</home/pang/md/nvim/nvim自定义命令.md>)。快捷键同步速查数据和必要的 Which-key 分组；故障根因写排障历史。已删除的独立快捷键、Spring 实操及依赖清单文档不重新创建，也不维护 Obsidian 中的旧副本。
