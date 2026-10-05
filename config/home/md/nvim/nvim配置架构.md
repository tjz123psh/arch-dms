# Neovim 配置架构

> 本文档描述整个 Neovim 配置的组织结构、加载顺序和设计约定。

## 加载顺序

```
init.lua
  ├── vim.g.mapleader = " "           ← 先设 leader 键
  ├── vim.g.maplocalleader = "\\"     ← 设本地 leader 键（预留）
  ├── require("core")                 ← 加载 core/init.lua
  │     ├── options.lua               ← 编辑器全局选项
  │     ├── diagnostics.lua           ← setup()：诊断显示与 LSP 日志
  │     ├── filetypes.lua             ← 自定义文件类型识别
  │     ├── keymaps.lua               ← 全局快捷键
  │     ├── commands.lua              ← 自定义命令；调用 projects.setup() / spring_wizard.setup()
  │     ├── autocmds.lua             ← 自动命令
  │     └── cjk_punct.lua            ← 中文标点输入即转半角
  ├── require("core.lazy")           ← 启动 lazy.nvim
  │     └── lazy 自动加载 lua/plugins/
  │           ├── *.lua               ← 顶层文件自动识别
  │           ├── */init.lua          ← 子目录自动识别
  │           └── 其他 .lua           ← 需由父级 init.lua 手动 require
  └── if neovide → require("neovide")
```

## 目录树

```
~/.config/nvim/
├── init.lua                    ← 入口文件
├── lazy-lock.json              ← 插件版本锁定
│
├── lua/
│   ├── core/
│   │   ├── init.lua            ← 按顺序加载核心模块
│   │   ├── lazy.lua            ← lazy.nvim 启动和配置
│   │   ├── options.lua         ← 全局设置（行号、缩进、搜索等）
│   │   ├── diagnostics.lua     ← 诊断配置、插入模式恢复显示、LSP 日志级别与轮转
│   │   ├── projects.lua        ← 项目历史、DirChanged 与 :Projects；commands 调用 setup()
│   │   ├── ui.lua              ← soft/pink 共用色板、:PickerSkin、ColorScheme；snacks 调用 setup()
│   │   ├── filetypes.lua       ← gotmpl、mdx、docker-compose/gitlab/helm YAML
│   │   ├── keymaps.lua         ← 全局快捷键（窗口、保存、搜索等）
│   │   ├── cheatsheet.lua      ← 快捷键速查浮动窗口（<leader>hk 打开/关闭）
│   │   ├── commands.lua        ← 自定义命令及 projects/spring_wizard 的 setup 调用
│   │   ├── autocmds.lua        ← 自动命令（文件类型、插入模式事件）
│   │   ├── cjk_punct.lua       ← 中文标点输入即转半角（InsertCharPre + v:char；:CJKPunct / :CJKPunctFix）
│   │   ├── input_boxes.lua     ← 输入类浮窗的统一几何（snacks 输入框 ↔ noice 命令行框：同长、同行）
│   │   ├── lsp_on_attach.lua   ← LSP 附加时的通用键位与诊断配置（lspconfig 与 jdtls 共用）
│   │   ├── language_actions.lua ← 跨语言 Ra 重构列表 / ot 整理导入，保留 Java jdtls 增强
│   │   ├── spring_wizard.lua   ← Spring Boot 项目向导（11 步、snacks.picker 版；:SpringBootCreate）
│   │   ├── java_main.lua       ← Java 主类扫描 + spring-boot:run / bootRun 主类参数解析（<leader>sr 的纯逻辑层，零 UI）
│   │   ├── java_test.lua       ← Treesitter 测试类/方法定位，识别失败即停止
│   │   ├── java_terminals.lua  ← 按项目/用途/主类持有终端，忙碌保护与安全重启
│   │   ├── java_debug.lua      ← 捕获 jdtls 客户端查询主类/运行时/classpath，含错误与超时出口
│   │
│   ├── neovide.lua             ← Neovide GUI 专用：透明度、字体、光标动画、缩放快捷键
│   │
│   └── plugins/                ← 插件配置，每文件管理一个或一组插件
│       ├── theme.lua           ← catppuccin 主题
│       ├── treesitter.lua      ← nvim-treesitter 语法高亮
│       ├── completion.lua      ← blink.cmp + 原生 vim.snippet + friendly-snippets
│       ├── mason.lua           ← mason 工具安装器
│       ├── mason-tool-installer.lua ← 调试器自动安装列表
│       ├── lsp/init.lua        ← nvim-lspconfig：启动已安装的语言服务
│       ├── mason-lspconfig.lua ← 手动 LspInstall/LspUninstall，启动时不加载
│       ├── flash.lua           ← flash.nvim 屏幕跳转
│       ├── format.lua          ← conform.nvim 自动格式化
│       ├── filetree.lua        ← neo-tree.nvim 文件树
│       ├── bufferline.lua      ← bufferline.nvim 标签栏
│       ├── statusline.lua      ← lualine.nvim 状态栏
│       ├── dashboard.lua       ← alpha-nvim 欢迎页
│       ├── noice.lua           ← noice.nvim 命令行美化
│       ├── snacks.lua          ← snacks.nvim（picker + input：接管 vim.ui.select/ui.input，其余模块显式关闭）
│       ├── devicons.lua        ← nvim-web-devicons 图标补齐（application.properties、*.gotmpl）
│       ├── whichkey.lua        ← which-key.nvim 快捷键提示
│       ├── autopairs.lua       ← nvim-autopairs 自动括号
│       ├── indentline.lua      ← indent-blankline.nvim 缩进线
│       ├── neotab.lua          ← neotab.nvim Tab 跳出括号
│       ├── betterescape.lua    ← better-escape.vim jk 不延迟
│       ├── project.lua         ← project.nvim + monkey-patch（启动即初始化项目历史）
│       ├── terminal.lua        ← toggleterm.nvim 浮动/分屏终端
│       ├── sidekick.lua        ← sidekick.nvim：在 nvim 里跑 AI CLI（codex/opencode/grok；只启用 CLI，不接 Copilot）
│       ├── markdown.lua       ← render-markdown.nvim：原编辑区美化（<leader>Mp 仅切换当前缓冲区）
│       ├── dap/init.lua        ← nvim-dap + nvim-dap-ui + nvim-dap-virtual-text 调试器
│       └── lang/
│           ├── init.lua        ← 聚合入口
│           ├── cpp.lua         ← clangd 扩展 + codelldb C/C++/Rust 调试
│           ├── java.lua        ← nvim-jdtls + Java 测试/调试
│           ├── go.lua          ← gopls + delve Go 调试
│           ├── springboot.lua  ← Spring Boot 补全 / 类生成 / 向导
│           └── rust.lua        ← rust_analyzer 扩展 + codelldb Rust 调试
```

## 插件配置约定

### 核心模块职责

- `core/init.lua` 调用 `core.diagnostics.setup()`，诊断与 LSP 日志从 options 分离，保留现有显示和轮转策略。
- `core/commands.lua` 调用 `core.projects.setup()`，项目历史、`DirChanged` 和 `:Projects` 集中管理；四层只追加保护不变。
- `plugins/snacks.lua` 调用 `core.ui.setup()`，皮肤命令、`ColorScheme` 和 soft/pink 色板集中维护；Spring 向导读取相同色板。
- grep 的布局独立构造，不深合并 select 布局数组；≥120 列左右排列列表/预览，窄屏上下排列。其他 picker 保持紧凑、键位不变。
- `:R` 只 `luafile` 当前磁盘文件，不清 `require` 缓存、不保证应用插件 spec；修改插件配置后保存并重启是可靠方式。

### opts 与 config 的选择

| 方式 | 适用场景 | 示例 |
|------|----------|------|
| `opts = { ... }` | 简单插件，直接给 setup() 传参 | dashboard.lua、autopairs.lua |
| `opts = function(_, opts)` | 需合并或修改 opts | cpp.lua 扩展 clangd |
| `config = function(_, opts)` | 多步骤逻辑、注册快捷键 | lsp/init.lua、java.lua |

### 延迟加载方式

| 方式 | 用途 | 示例 |
|------|------|------|
| `lazy = false` | 必须立即加载 | 主题、mason、lspconfig、blink.cmp、project.nvim、noice、snacks |
| `event = "UIEnter"` | UI 出现后加载 | 状态栏 |
| `lazy = false` | 启动时加载 | treesitter（新版不支持 lazy-loading） |
| `event = "InsertEnter"` | 进入插入模式时加载 | autopairs、betterescape、neotab |
| `event = "VeryLazy"` | 启动后加载 | flash、indentline、whichkey |
| `event = "BufWritePre"` | 保存前加载 | conform（格式化） |
| 条件 `event = "VimEnter"` | 无文件参数时加载 | alpha 欢迎页；有文件时仍保留 `:Alpha` / `:A` 按需加载 |
| `ft = "java"` / `ft = "markdown"` | 打开特定类型文件时加载 | nvim-jdtls / render-markdown.nvim |
| `cmd = { "LspInstall", "LspUninstall" }` | 手动安装/卸载时加载 | mason-lspconfig（mason 本身仍启动初始化 PATH） |
| `keys = { ... }` | 按到对应键时加载 | sidekick、bufferline；注释使用 Neovim 内置 `gc`/`gcc` |
| `keys + event` | 混合触发 | conform（event + keys） |

### 子目录加载规则

- `dap/init.lua` — 被 lazy 自动加载（`*/init.lua` 模式）
- `lsp/init.lua` — 被 lazy 自动加载
- `lang/init.lua` — 被 lazy 自动加载，然后在内部 `require` 同目录的 `cpp.lua`、`java.lua`、`go.lua`、`springboot.lua`、`rust.lua`

```
lua/plugins/lang/
├── init.lua    ← lazy 自动加载
├── cpp.lua     ← init.lua 通过 require 手动加载
├── java.lua    ← init.lua 通过 require 手动加载
├── go.lua      ← init.lua 通过 require 手动加载
├── springboot.lua ← init.lua 通过 require 手动加载
└── rust.lua    ← init.lua 通过 require 手动加载
```

## 特殊处理

| 位置 | 问题 | 处理方式 |
|------|------|----------|
| project.lua | `vim.lsp.buf_get_clients()` 在 0.10 已废弃 | 运行时 monkey-patch `find_lsp_root`，不修改插件文件 |
| project.lua | 上游异步读和截断写可能使并发实例丢失历史 | 写守卫只追加磁盘缺项，永不调用上游截断写，异常只提示；跨实例重复行由读取端去重。 |
| core/projects.lua / project.lua | 项目列表首次打开需有内容，且不能与内置源冲突 | project.nvim 启动初始化；`:Projects` 同步只读历史，用 `source = "project-history"`、`project_dir` 字段和紧凑布局，回车切项目并刷新文件树。 |
| core/projects.lua / project.lua | 项目历史不能依赖可被截断的单一文件 | 四层保护：① `~/.local/state/nvim/project-history.list` 只追加副本；② 副本 ∪ 插件历史 ∪ 会话项目并集；③ 打开列表时 append 回填；④ 插件写守卫永不截断。`DirChanged` 记录当前项目，重构保留全部保护。 |
| core/projects.lua | `:Projects` 的行是纯文本（名字 + 绝对路径），框宽固定半屏，宽终端上大片空白 | 行改富文本：文件夹图标（蓝）+ 项目名（亮、按最长名对齐）+ 父目录（灰、`~` 缩写）；框宽**贴合内容**（`[40, min(96, columns-8)]`）；当前项目置顶 + 蓝色名字 + `当前` 徽标 |
| project.lua / filetree.lua | 从项目列表切换项目后文件树仍停在旧目录 | neo-tree `filesystem.bind_to_cwd = true`，且 project.nvim `set_pwd()` 成功后主动刷新已加载的 neo-tree filesystem state |
| lsp/init.lua | jdtls 不由 lspconfig 管理 | `setup = { jdtls = function() return true end }` 跳过 |
| mason-lspconfig.lua | 启动依赖链中的 setup 会刷新注册表，过期/缺失时联网 | 移出启动依赖链，改手动命令加载，依赖 Mason 保证初始化顺序。批量 LSP 清单迁到 mason-tool-installer，关闭其 mason-lspconfig 集成，保留 run_on_start=false；显式手动安装/更新仍可刷新注册表。 |
| lsp/init.lua | `vim.diagnostic.goto_prev/goto_next` 在 0.12 废弃 | `[d`/`]d` 改用 `vim.diagnostic.jump({ count = ±1, float = true })` |
| core/filetypes.lua | LSP health 报 Unknown filetype | 用 `vim.filetype.add()` 注册 gotmpl、markdown.mdx、docker-compose/gitlab/helm YAML |
| java.lua | 0.12+ `vim.lsp.start` 不解析函数式 root_dir | 在 config() 中预求值为字符串再传 opts.root_dir |
| java.lua | 同一会话切不同 Java 项目时 workspace_dir 不更新 | `cmd_base` 保存基础 cmd，`build_cmd()` 每次 start_or_attach 时重新拼装 `-data` 参数，按项目名隔离 workspace |
| autopairs.lua | 特殊界面不宜自动补全 | `opts = {}`（blink.cmp 在无补全窗口时正常触发） |
| betterescape.lua | 插件的 vim.g 变量需在 setup 前设置 | 用 `config` 而非 `init` 也行，在 InsertEnter 时加载 |
| format.lua | 保存自动格式化 500ms 偏短，Java/C++/Rust 大项目易超时 | `timeout_ms = 2000` |
| format.lua | LSP 可能抢先于显式 formatter | `lsp_format = "fallback"`，显式工具优先，LSP 兜底 |
| format.lua | Go 使用哪个格式化入口 | 当前不登记独立 Go formatter，由 gopls 提供格式化（启用 `gofumpt = true`）。`fallback` 看的是解析后是否存在**可用** CLI formatter：没有且有支持格式化的 LSP 就回退；登记了缺失工具不会阻止回退。若换独立工具，安装后再登记；可用 CLI 执行失败并不等于自动回退。 |
| bufferline.lua | `bdelete!` 会丢未保存修改 | 改为 `bdelete %d`。⚠ **2026-09-28（审查 A03）再改**：原生 `:bdelete` 会把该 buffer 所在的**窗口一起关掉**（真 pty 实测 2 窗口→1、3 窗口→1），点标签页的 × 就砸掉分屏 ⇒ 改用 `:BufDelete %d`（`core/commands.lua`，内部走 `Snacks.bufdelete`，删完把窗口切到相邻 buffer、布局不变）。Snacks 的 `bufdelete.enabled = false` 只是不注册它自带键位/不显示 setup 警告，**不影响 `Snacks.bufdelete()` 调用**（实测可用） |
| options.lua | 退出含未保存修改的缓冲区时容易误操作 | `confirm = true`，退出/关闭前明确确认 |
| dashboard.lua | `cond = argc == 0` 会让带文件启动后的 `:A` 也不可用 | 只给 `VimEnter` 事件加条件，保留 `Alpha` 命令按需加载；窄窗口使用紧凑 Logo/页脚 |
| treesitter.lua | Treesitter 可能早于 Mason setup，找不到已安装的 CLI | 安装解析器前检测并补入 Mason bin 路径；补齐 JavaScript 解析器 |
| treesitter.lua | 写前端时缺 `.ts`/`.tsx`/`.vue`/`.svelte`/`.scss` 解析器；且本机 GitHub 下载必须走 Clash 代理（`127.0.0.1:7890`），代理没开时自动下载会失败并**每次启动重试刷屏** | `ensure_installed` 补 typescript/tsx/vue/svelte/scss 并加入 `highlight_filetypes`；缺失时的自动下载加 **6 小时节流**（stamp 文件 `~/.local/state/nvim/treesitter-install-stamp`），节流期内只发一条 INFO。手动安装：`HTTPS_PROXY=http://127.0.0.1:7890 nvim --headless -c "lua require('nvim-treesitter').install({'tsx'}):wait(420000)" -c "qa!"` |
| filetree.lua | `r` 被错误映射成 move，与界面和文档不一致 | `r` 恢复重命名，`m` 单独用于移动 |
| sidekick.lua | 需要 AI CLI，不引入 Copilot 或 mux | `nes.enabled = false`，当前不用 tmux/zellij。`<leader>aa` 只切换显示/隐藏，隐藏不停止 job；`<leader>ad` / `:Sidekick cli close` 走 detach → terminal close，停止对应终端 job 并清理 buffer。健康检查须先加载插件；未启用 Copilot LSP 的提示属预期。 |
| snacks.lua | 搜索/选择器两套 UI 并存（dressing+nui / telescope）互相打架、观感有天花板 | UI 收敛到 snacks 一家：`picker.ui_select = true` + `input.enabled = true`，telescope/dressing 的 spec 与磁盘文件均已删除（`:Lazy! clean`）；搜索键改 `Snacks.picker.files/grep/buffers/help/files({cwd=配置目录})` |
| snacks.lua | ⚠ snacks 对 `win.*.keys` 是**整体替换**语义，只写几个键会干掉默认的 `<CR>`/`<Tab>`/`<Esc>`（实测向导按 CR 不确认、picker 关不掉） | 从 `snacks.picker.config.defaults` 拷贝后再 merge（`vim.tbl_extend("force", ...)`），并追加 `<C-j>`/`<C-k>`/`<C-n>`/`<C-p>` 与 i 模式的 `<Esc>`；必须写在 `config()` 里（spec 解析期 snacks 不在 rtp） |
| snacks.lua | picker 同 `source` 会互相 dedupe（新实例返回 nil） | 各自用独立 source：向导 `spring-wizard`/`spring-wizard-deps`、jdtls 多选 `jdtls-pick-many`、项目列表 `project-history`（⚠ **不能**用 snacks 内置同名源 `projects`，见本节第一行的警告）；`vim.ui.select` 占 `select` 源 |
| snacks.lua | 内容搜索需要预览，不能让 select 的布局数组残留旧节点 | 独立构造 grep 布局，不深合并 select 数组；宽屏（≥120 列）左侧输入/列表、右侧预览，窄屏上方输入/列表、下方预览。其他 picker 继续紧凑、无默认预览，键位不变。 |
| core/ui.lua / snacks.lua | picker 配色和向导需要一致，切主题不能丢皮肤 | `core.ui` 集中 soft/pink 色板、`:PickerSkin` 和 `ColorScheme`，snacks 调用 setup，向导读取相同色板；默认 soft，普通 picker 继续使用 `picker_compact`。 |
| lazy.lua | checkhealth 报 luarocks/hererocks 警告 | `rocks = { enabled = false }` |
| options.lua | checkhealth 报 node/python/perl/ruby provider 警告 | `vim.g.loaded_*_provider = 0` |
| options.lua | shell 写死路径不够稳 | `vim.fn.exepath("bash")` 找到 bash 时再设置 |
| core/cheatsheet.lua | 原速查窗口样式简单、小终端可能越界 | 改为严格受终端宽高约束的浮动命令面板；分区、快捷键列高亮；`<leader>hk` 再按关闭，`q`/`Esc` 关闭 |
| core/diagnostics.lua | 长诊断和同行多条消息需要可读展示 | `severity_sort = true`；光标行 WARN/ERROR 用 `virtual_lines`，按窗口宽折行、保留前导缩进和纯指针行，最多 12 行；诊断浮窗保留完整内容。行尾文字只显示 WARN 及以上。 |
| core/diagnostics.lua | `<C-c>` 退出插入模式不触发 `InsertLeave`，诊断可能暂时消失 | 保留 `update_in_insert = false`，用 `ModeChanged`（`i*:n*`）补刷窗口可见 buffer 的诊断，避免对全部 buffer 重绘。 |
| theme.lua | nvim 0.12 会给带 `unnecessary` tag 的诊断（jdtls 的未使用字段/局部变量/import）额外叠一层 `DiagnosticUnnecessary`（`diagnostic.lua`），而 `runtime/colors/vim.lua` 把它 link 到 `Comment` ⇒ **整段文字**被染成灰 `#9399b2` + 斜体；jdtls 每次编辑后 300~700ms 重新发布诊断 ⇒ 「刚写下的字段/常量变灰再变回来」 | `colorscheme` 之后 `vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})`，并挂一条 `ColorScheme` autocmd 防手动切主题后失效：文字保持 treesitter 原色，tag 诊断仍有常规严重级别下划线；`DiagnosticDeprecated` 实测只有 `sp`+删除线、不染字色，保持原样 |
| format.lua | Java 半成品代码常无法被 google-java-format 解析 | `filetype == "java"` 时有意跳过保存自动格式化，需手动 `<leader>F` |
| terminal.lua | `<leader>tt/th/tv` 共用一个实例会互相顶替、丢失方向与尺寸 | 三键分别绑定 terminal id 1/2/3（浮窗 20 行 / 水平 15 行 / 垂直宽度自适应 `max(30, min(80, columns*0.45))`：80 列→36，200 列→80）；浮窗内切换分屏会关闭浮窗 |
| noice.lua | 命令行浮窗写死宽度会在窄终端被裁边（历史：写 78 时总宽 82 超出 80 列） | cmdline 改 `width = "auto", min_width = 40, height = "auto"`：noice 只在 auto 时才把宽度夹进 `columns-4`，80 列实测 44 列居中；`vim.fn.input` 浮窗标题 " Input " → " 输入 " |
| snacks.lua | `vim.ui.select` / `vim.ui.input` 需要唯一提供者（neotree 输入、LSP 重命名、代码操作多选、向导文本步骤都走它） | snacks 在 **UIEnter** 接管（真 TTY 实测来源 `snacks/picker/init.lua`、`snacks/input.lua`，窗口名 `snacks_picker_*`/`snacks_input`）；headless 测不到接管结果 |
| dap/init.lua | dap-ui 侧栏写死 45 列，80 列终端会挤掉编辑区 | 侧栏宽改 `max(28, min(45, floor(columns*0.32)))`（80 列→28，200 列→45），仍放右侧 |
| dashboard.lua | logo 阈值 68 会让 58~67 列窗口退化成纯文字 | 阈值降到 58（logo 实测宽 52 列）；页脚 `>= 80` 列才显示完整 cwd，否则只显示目录名 |
| filetree.lua | 文件树宽度写死列数不适应窄窗口 | `width` 改为函数 `max(20, min(35, floor(columns*0.4)))`（80 列→32，60 列→24，200 列→35） |
| completion.lua | 补全文档窗一停就弹、行数过高会挡代码 | `auto_show_delay_ms = 800`、`window = { max_height = 12, desired_min_width = 40, border = "rounded" }` |
| core/cjk_punct.lua | 插入模式下打出的中文标点（`，。；：！？`…）不会自动变半角，粘贴进来的也不会 | 2026-09-25 新增：用 `InsertCharPre` 改写 `vim.v.char`（Neovim 0.8+）实现「输入即转」，零依赖、无延迟；默认在 `markdown`/`text`/`gitcommit`/`help` 里**不转**（`exclude_ft` 可清空）；`:CJKPunct` 开关、`:CJKPunctFix` 转换已有内容。⚠ 没有现成插件（`autocorrect` 规则相反：把 CJK 旁标点转**全角**）；⚠ Lua 的 `[...]` 字符类按**单字节**匹配，多字节汉字必须按「一个完整 UTF-8 字符」匹配 |
| lang/java.lua | jdtls 的多选弹窗本来走 `vim.fn.input`：输入编号 + Enter 勾选，**Esc 不是取消而是「按当前勾选继续」** | 已 override `jdtls.ui.pick_many` 为 snacks picker：`<Tab>` 勾选 / `<CR>` 确认 / `<Esc>` 取消（协程让出，失败自动回退上游）；预勾选（构造器已选中的字段显示 ●）用 `list:set_selected()` 而不是逐个 `toggle`（后者会与首帧渲染抢状态，导致预勾选后 Tab 无法追加），实测可正常追加/取消；代码操作不再经过 noice cmdline，上一条的标题改动只对其它 `input()` 路径生效 |
| lang/java.lua | `:JavaSetRuntime` 依赖 `settings.java.configuration.runtimes`，为空时 `jdtls.set_runtime()` 只 warning、不切换 | 在 `settings.java` 里列出本机真实存在的 JDK（`JavaSE-21` 默认、`JavaSE-1.8`；路径不存在自动跳过）；实测客户端收到 2 个 runtime、`:JavaSetRuntime` 可切换且 `Tab` 补全两个 |
| lang/java.lua | ⚠ 2026-09-25 真机复验发现的第二处：命令是 `nargs = "?"`，**不带参数时 `p.args` 是空字符串**（Lua 里为真）⇒ 上游 `set_runtime` 的 `if runtime then` 走「按名匹配」分支，只报 `Provided runtime `` not found…`、**不弹选择列表** | 改为 `jdtls.set_runtime(p.args ~= "" and p.args or nil)`（无参数传 nil 才会走 `ui.pick_one_async` 列出 runtimes）；修复后 `:JavaSetRuntime` 弹出 Runtime> 列表、两条都在 |
| lang/java.lua | 打开 `.java` 会**同步**加载 nvim-jdtls + nvim-dap + dap-ui + virtual-text + nio（`ft` 链里无条件 `require("dap")` + `jdtls.setup_dap()`），startuptime 实测 dap/nio 相关条目 43 条 | 新增幂等 `ensure_java_dap()`：Java 的 DAP 接线推迟到 `<F5>` / `<leader>Jg` / `<leader>Jd` 三个入口再做；实测打开 .java 时那四个插件**不再加载**（0 条），首次调试才付 ≈4.7ms；`<F5>` 断点→变量、`<leader>Jg` 跑测试均复验通过（2026-09-25 第十二轮） |
| lang/java.lua | ⚠ 2026-09-25（§29）：client 级 `config.handlers['workspace/executeClientCommand']` **会盖掉** nvim-jdtls 的全局转发（`client.lua`），而 spring-boot.nvim 的 classpath 握手命令 `vscode-spring-boot.ls.start` 注册在**全局** `vim.lsp.commands` ⇒ 握手被静默吞掉（无 beans/endpoints/yml 补全），且初始化期请求永不回会让 `<F5>` 报 `Could not resolve java executable` | handler 里自己复刻转发：先 `client.commands[cmd]`、再全局 `vim.lsp.commands[cmd]`，命中就 `pcall` 执行并把返回值回给服务端；**未知命令回 `vim.NIL`（绝不能 `return nil`：runtime `rpc.lua` 会抛错且请求永不回）**；`_java.reloadBundles.command` 回**空表**（jdtls 按 `instanceof List` 分流，回 null 会记 `Unexpected result`） |
| lang/java.lua | nvim 0.12 **自动启用**服务器支持的全部 LSP capability（`runtime/lua/vim/lsp/client.lua` 遍历 `vim.lsp._capability.all`），jdtls 的语义 token 一直开着；其 extmark 优先级 125 > treesitter 100 ⇒ 实测「全大写 `static final` 常量」在编辑后 60~230ms 从 `@constant.java` teal `#94e2d5` 跳成 `@lsp.type.property` lavender `#b4befe`，用户报「写 Java 时代码颜色变来变去」（2026-09-26） | `java_on_attach` 包装里 `vim.lsp.semantic_tokens.enable(false, { bufnr = bufnr })`（按 buffer 关；buffer 级标记 `vim.b[bufnr]._lsp_enabled_semantic_tokens=false` 能让**之后**才 attach 的 spring-boot LS 同样不启用）；Java 仍有完整 treesitter 高亮，`lsp.log` 里 `-32801 Document changed` 由每次运行 6~10 条降到 0 |
| core/java_test.lua + lang/java.lua | 旧的“两行拼接＋向上找”仍会把多行参数/同行注解的方法识别成前一个测试 | 改为 Java Treesitter 的当前 `method_declaration` 及类名字段；参数、注解、throws、方法体均按包含关系定位。缺解析器、语法错误、方法间空白不猜；成员内部类使用二进制类名 `$` 并对完整 selector 做 shellescape，匿名类/局部类拒绝。 |
| core/java_main.lua + lang/java.lua | 多入口的 Spring Boot 项目（双进程 Api + Worker）盲跑 `spring-boot:run`，构建工具直接报 `Unable to find a single main class from the following candidates [...]`（2026-10-02 实测） | `<leader>sr` 改成**先认主类再启动**：扫 `src/main/java` 下所有带 `main` 的类（测试源集不算），只有一个直接启动、多个弹 snacks 选择框（标出 `[终端 N]`、`← pom 默认`、`● 已在跑`，并附一项「▶ 全部启动」）。主类参数按 pom 形态二选一：pom 写了 `<mainClass>${main.class}</mainClass>` 用 `-Dmain.class=`，没写用 `-Dspring-boot.run.main-class=`（Gradle 的 `bootRun` 只能由 `build.gradle` 指定主类，会提示但不阻断）。终端由 `core/java_terminals.lua` 按真实项目路径＋用途＋主类分配，编号从 4 起避开已占用/预留编号（无循环上限，扫描排序改变不串号），构建/测试独立；通用 1/2/3 不动。同类再运行先 Ctrl-C 并等旧进程退出（10 秒超时），不向旧进程灌命令；构建忙时只提示。shell exit 后保留旧输出缓冲区、另建终端，窗口 close 则复用存活 shell。重开用 `:<编号>ToggleTerm`，不是 `<leader>th`；「全部启动」只读取本次启动的输出（64KB 上限），按顺序等前一个出现 `Started …` 再起下一个，避免两个 Maven 同时写 `target/`。扫描与参数解析在 `core/java_main.lua`（纯逻辑，可 headless 断言）。⚠ 槽里「有没有东西在跑」不能看 job（toggleterm 是常驻 shell），要读 `/proc/<shell_pid>/…/children` 判空 |
| core/java_debug.lua + lang/java.lua | F5 曾复用跨项目的 `dap.configurations.java`；上游 setup 扫描只合并、不删除旧项目条目 | 每次直连当前缓冲区捕获的 jdtls 客户端查询主类、Java、preview 和 classpath，保留精确 LSP root 为 cwd；不读写全局 DAP 配置。请求代次、缓冲区名、客户端 id/root 守卫淘汰旧结果；每次查询 15 秒超时、空列表最多尝试 4 次；切换缓冲区/已有会话时不自动启动。F5 活动会话继续；Jd 仅查询报告数量；手动兜底取消/空输入不启动。 |
| core/input_boxes.lua | 两个「打字用的浮窗」由不同插件画、宽度口径不同：新建文件的输入框（snacks 默认样式写死 `row = 2`）贴着屏幕顶部，命令行框只有 44 列——既不齐也不等长（2026-09-26 用户截图） | 新增共享模块当唯一事实源：`M.width()`（snacks 的**内容宽**口径，总宽 = width + 2）、`M.noice_min_width()`（noice 口径）、`M.center_row() = floor((lines − 3) / 2)`。⚠ **2026-09-28（审查 U01）实测修正了两处**：① 盒模型偏移量是 **4 不是 2** —— 114 列下配 `min_width=78` 实测外框 82、内容 78 ⇒ 78+4=82，80 列下配 72 实测外框 76 ⇒ 72+4=76，两处都对齐；旧实现按「padding 2 + border 2」算成 min_width=78，**两个框因此一直差 2 列**（80 列实测：输入框 74 vs 命令行 76）。现在 `noice_min_width = 内容宽 − 4`，80 列下两框同为 74 ✅。② 宽度不再写死 80：改成 `clamp(columns − 6, 30, 80)`，因为**旧配置在 80 列终端上命令行外框 82 被屏幕硬裁掉 2 列**（真 pty 实测 `cfg.w=82` 而 `实宽=80`，右边框消失、右端出现截断标记），现在 80 列下总宽 76、完整显示；114 列下仍是 82，宽屏零回归。⚠ snacks 的 `win.row/width` 支持函数（开窗时求值、跟随 resize），noice 的 `min_width` **只能是数字**（`noice/util/nui.lua` 的 minmax 直接进 `math.max`）⇒ noice 那侧是**配置加载时的快照**，改终端大小需重启才跟上。⚠ 遗留未修：实测两个框**差 1 行**（80×24：输入框 row=10、命令行边框 row=11；114×30 是 13 vs 14），这条差异**先于本轮存在**（旧宽度下也都是差 1 行），要对齐得把 `center_row()` 对两侧分别取值 |
| core/options.lua | nvim 的 `:terminal` 只给子进程 `TERM=xterm-256color`、**不设 `COLORTERM`** ⇒ grok/opencode 这类 TUI 判定"非真彩色"，会隐藏需要 truecolor 的主题（grok 5 个只显示 2 个） | 启动时补 `vim.env.COLORTERM = "truecolor"`（用户已显式设过则不覆盖）。实测 `:terminal grok doctor`：修复前 `color 256 / themes 2/5`，修复后 `color truecolor / themes all` |
| core/diagnostics.lua | LSP 日志即使限制级别也会长期增长 | 日志级别 ERROR；启动时超过 5MB 就轮转为 `lsp.log.1`，仅保留上一份轮转日志。 |
| core/lazy.lua | lazy.nvim 的更新检查器默认会在**启动时**对全部插件跑 `git fetch`（与「启动期不联网」的约定冲突，且 `notify=false` 让失败静默） | `checker = { enabled = false }`；要看更新手动 `:Lazy check`（代价：`:Lazy` 界面里的更新徽标不再自动刷新） |
| core/autocmds.lua | 自动保存只写**当前**缓冲区 ⇒ 后台改过的文件仍会让 `:qa` 弹"已修改未保存"确认 | `QuitPre`/`VimLeavePre` 用 `vim.api.nvim_buf_call(buf, …)` 保存**所有**被改过的缓冲区（`BufLeave`/`FocusLost` 仍只存当前）；实测两个 buffer 都改过时 `:qa` 无 E37、两份文件都落盘。⚠ `:{N}write`（缓冲区号当计数）实测是静默 no-op，别用它 |
| core/autocmds.lua | 丢弃退出漏识别修饰符/缩写/ZQ；分屏 q! 后标记持续残留 | 用 nvim_parse_cmd 解析直接输入的 Ex 命令，在每次 QuitPre 按顺序取退出意图（保存/丢弃不混用），cquit 单独在 VimLeavePre 处理。WinClosed 后立即解除该窗口的保存抑制，SafeState 清理失败/已完成命令的剩余状态；不使用会被 vim.wait 提前运行的 schedule 清理。ZQ 通过同步 quit_without_save 保护范围执行 quit!，返回/报错均清理；取消和搜索命令行不设退出意图。 |
| lang/init.lua | 各语言 spec 用裸 `pcall(require, …)`，某门语言整份加载失败会**静默消失**（"某功能就是不生效"却毫无线索） | 抽出 `load_lang(name)`：失败时 `vim.notify(…, ERROR)` 并返回 `{}`，其余语言继续加载 |
| lang/springboot.lua | `spring-boot.nvim` 写死 `lazy = false`：让同 spec 的 `ft` 变死配置，并把 nvim-jdtls/DAP 拖进启动期；`springboot-nvim` 只声明 `ft` | `spring-boot.nvim` 改用 lazy 的 `cmd` 桩（`cmd = { "SpringBoot" }`）+ 原 `ft`：启动期命令就存在，插件真正调用时才加载；`:SpringBootCreate` 由 `core/spring_wizard.lua` 在 core 层注册。`springboot-nvim` 2026-09-25 起只保留类生成与增量编译（`<leader>sP`/`:SpringBootNewProject` 因原版向导的 Boot 4 版本号 bug 被删，`cmd` 桩随之移除） |
| lsp/init.lua | 审查报告（A01）称 `library = nvim_get_runtime_file("", true)` 会把「所有已安装插件」喂给 lua_ls、导致 CPU/内存飙升 | **报告结论已证伪**（实测只展开 25 条、不含插件 `lua/` 子目录；「内存上 GB」无实测支撑），但仍按建议引入 `lazydev.nvim` 并收窄范围（2026-09-28）：新增依赖 `{ "folke/lazydev.nvim", ft = "lua", opts = {} }`，`library` 从 `nvim_get_runtime_file("", true)` 改为 `nvim_get_runtime_file("lua", true)`（**递归找 `lua/` 模块根**：25 → 17 条，插件 `require()` 补全仍保留，去掉的是插件根目录/文档/测试）。lazydev 走 `workspace/configuration` 应答（`lazydev/lsp.lua` 的 `on_workspace_configuration`）按 buffer 动态给 `Lua.workspace.library`，默认含 `$VIMRUNTIME` ⇒ Neovim API 类型不丢。实测打开 `core/keymaps.lua` 后 lua_ls 成功 attach（root = 配置目录），插件数 37→38，启动干净、checkhealth 无新增告警 |
| lsp/init.lua | `:checkhealth vim.lsp` 常驻 `Unknown filetype 'xsl'`：nvim-lspconfig 给 lemminx 的默认 filetypes 把"扩展名当 filetype"，而 runtime 把 `.xsl`/`.xslt` **都**识别成 filetype `xslt` | 显式覆盖 `lemminx = { filetypes = { "xml", "xsd", "xslt", "svg" } }`；健康检查里该警告清零（0 条） |
| core/diagnostics.lua | 诊断浮窗消息末尾会带 `[603979884]` 这类 jdtls 内部诊断码（Neovim 默认 `float.suffix` 追加 ` [code]`） | 自定义 `float.suffix`：**只**丢掉纯数字码，保留 `E0308`、eslint 规则名等有意义的文字码 |
| statusline.lua | 状态栏看不到 LSP 客户端状态：jdtls 是在索引、就绪还是崩了，只能 `:LspInfo`（审查 G03） | `lualine_x` 加 `{ "lsp_status", icon = "", show_name = true }`（2026-09-28）。**lualine 自带该组件**（`lualine/components/lsp_status.lua`，本机实测 `require` 成功），不需自己写；它监听 `LspProgress`、索引时转圈、就绪显示 `✓`。实测：无客户端时渲染 `""`（不占位）、mock 1 个客户端渲染 `"jdtls "`、2 个渲染 `"jdtls gopls "`；`get_config()` 里 `lualine_x = [diagnostics, lsp_status, filetype]`。不想要这个动画就删掉那一行 |
| statusline.lua | `disabled_filetypes` 里的 `neo-tree` 与 `extensions = { "neo-tree" }` 互斥：禁用优先 ⇒ 切到文件树时（`globalstatus` 下）整条状态栏空白，扩展永远轮不到生效 | `disabled_filetypes` 只保留 `alpha`；真 pty 实测 neo-tree 窗口状态栏恢复渲染（`LASTSTATUS=3`） |
| neovide.lua | 窗口不透明度原来只能改文件（`vim.g.neovide_opacity = 0.80`）；另两个「看似能持久化」的途径实测**都无效**（2026-09-29） | 加 `<leader>uo`：用 `vim.ui.select`（全机已被 snacks 接管）弹出八档预设 `1.00/0.95/0.90/0.85/0.80(默认)/0.70/0.60/0.50`，当前值标 `●`，当前值不在档位里（如手设 0.83）会自动补一项标「当前值」。**选完会持久化**：值写入 `stdpath("state")/neovide-opacity`（一行数字），启动时读它套用 ⇒ 选一次就定下来；文件不存在/损坏/越界则回落出厂默认 0.80（删文件即回默认）。⚠ 为什么要自己存：Neovide 的 `neovide-settings.json` 只存窗口几何、**不存不透明度**（实测：改成 0.5 → 退出 → 重启又回到默认）。⚠ 实测否掉的两条路：`:NeovideConfig` 打开的 `~/.config/neovide/config.toml` 与 `NEOVIDE_CONFIG` 环境变量在 Linux 上**均不被读取**（有/无该文件两次截图逐字节几乎相同，变量仍是默认 1）。⚠ 键位必须放 `neovide.lua` 而非 `core/keymaps.lua`：`core` 在 `init.lua` 里先于 `vim.g.neovide` 赋值加载，放那边注册不上（已在 `keymaps.lua` 顶部交叉注明）；好处是整个文件有 `vim.g.neovide` 守卫 ⇒ 终端 nvim 里这些键不存在 |
| markdown.lua / theme.lua | 用户本次明确选择直接美化编辑区，同时避免透明主题下的整块底色 | 使用 MeanderingProgrammer/render-markdown.nvim，Markdown FileType 自动加载，在原窗口渲染；普通/命令模式美化，插入/可视模式回源码，光标行 anti_conceal。标题 `backgrounds = {}`；代码块 `disable_background = true`、`style = "language"`、`border = "none"`，禁 sign；主题加入 `render_markdown` 集成。复用 Treesitter/web-devicons，LaTeX 暂不启用，不额外装工具。`<leader>Mp` 与 `:RenderMarkdown buf_toggle` 仅切当前缓冲区，`buf_enable` / `buf_disable` 同样仅当前缓冲区；`enable` / `disable` / `toggle` 是全局。旧 `:MdRender`、`<leader>Mt` / `<leader>Ms` 移除。历史上 2026-09-25 因整行底色等观感问题曾选独立 md-render 预览，这只是当时取舍，不再把“不能改编辑视图”当作当前要求；本次观感待用户确认，不承诺浏览器级图片/Mermaid/LaTeX |
| comment.lua（已删） | numToStr/Comment.nvim 停更 27 个月（2024-06 最后提交），而 Neovim 0.10+ 已内置注释操作符 | 删除 spec 并 `:Lazy! clean`：内置 `gc`/`gcc` 接管（旧 spec 的 `keys = {"gc"}` 桩映射本来会顶掉内置）。注意内置**没有** `gb`/`gbc` 块注释与 `gcO`/`gco`/`gcA` |

## 当前快捷键约定

菜单按功能区分适用范围：`通用 · …` 不限定语言；`LSP · …` / `格式化 · …` 是跨语言入口但依赖对应工具；`DAP · 调试` 目前接好 Java、C/C++、Go、Rust；`整理 · 按语言`（o）和 `重构 · 按语言`（R）共用入口；`Java · …`（G/J/m）、`Spring · …`、`Markdown · …` 是专用功能，`Neovide · 显示` 仅用于该 GUI。普通/可视模式使用相同分组名。无可用子项的组自动收起，全局 Spring 向导、Java 生成入口仍可从其它文件调用。速查顶部有相同图例。

只读回归：[whichkey_scopes.lua](</home/pang/.config/nvim/tests/whichkey_scopes.lua>) 用真实 which-key 和代表性映射检查 Java/Go/Rust/C/C++/Lua/Markdown/文本的菜单与普通/可视模式，并比对实际映射前后不变；不启动任何语言服务。

| 按键 | 说明 |
|------|------|
| `ZQ` | 放弃当前窗口修改并关闭，经过自动保存保护；不退出其它窗口 |
| `J` | 普通模式下移当前行，支持数字前缀 |
| `K` | 普通模式上移当前行，支持数字前缀 |
| `J` / `K` | 可视模式（含选择模式）下移/上移整块选中行，支持数字前缀，保持选择和缩进 |
| `<leader>j` | 合并下一行 |
| `gh` | LSP 悬浮文档 |
| `<leader>ca` | 所有可用代码操作；保持原有行为 |
| `<leader>Ra` | 仅列出当前可用重构；普通模式用光标，字符/整行可视模式用选区，始终确认后执行 |
| `<leader>ot` | 按语言整理导入；Java 调 jdtls，其余请求标准 source.organizeImports；单个动作直接执行，多个时选择 |
| `<leader>Rv/Rc/Rm/RV` | Java 原有的直接提取变量/常量/方法/重复表达式；未强行推广到其它语言 |
| `<leader>hk` | 打开/关闭个人快捷键速查浮动窗口 |
| `<leader>he` / `<leader>hh` | 最近的报错 / 全部消息历史（noice；接管 `vim.notify` 后 `:messages` 查不到报错） |
| `<leader>Mp` | Markdown：当前缓冲区编辑区美化开关（render-markdown.nvim；旧 Mt/Ms 移除） |
| `<leader>sp` | Spring Boot 项目向导：全局可用，不限 Java 缓冲区 |
| `<leader>sr` | Spring Boot：运行（自动识别主类，多个弹选择框、含「全部启动」；每个主类一个终端，已在跑的标 `●`） |
| `grr`/`gra`/`grn`/`gri`/`grt` | 0.12 内置 `gr` 前缀（`gr` 本身不再映射） |
| picker 内：`<CR>` / `<Tab>`·`<S-Tab>` / `<Esc>` / `<C-j>`·`<C-k>` / `<C-n>`·`<C-p>` | 确认 / 多选切换 / 一次关闭 / 上下移动（snacks 默认键 + 追加重叠键） |

### 跨语言动作的边界

[language_actions.lua](</home/pang/.config/nvim/lua/core/language_actions.lua>) 的按键由共享 LSP on_attach 注册，不依赖初始化时的静态 capability，避免漏掉 jdtls 动态注册能力。Java 局部 ot 也调用同一入口，附加顺序不会改变行为；Java 必须有当前缓冲区的 jdtls，才会调用原有增强整理。

通用部分复用 Neovim 原生 code_action：Ra 仅请求 `refactor` 及其子类，ot 仅请求 `source.organizeImports` 及其子类；服务端忽略过滤时客户端还会二次过滤。保留原生选区/编码转换、resolve、WorkspaceEdit 和客户端命令处理，不按显示标题猜动作。无服务时中文提示；无相应动作或无须改动时显示 `No code actions available`（没有可用代码操作），不会退回整文件格式化或任意 quickfix。矩形选区拒绝重构，请改用字符/整行选择。

入口通用不代表各语言能力一致；具体候选取决于服务端、代码位置和选区。Java 的直接提取键仍保留，测试/构建/Spring 专属键不变。

本机实服验证（2026-10-04，临时项目）：

| 语言/服务端 | ot 整理 | Ra 重构样例（非完整能力表） |
|---|---|---|
| Java / jdtls | 增强整理生效，删除未使用 import、保留使用中的 import | 提取变量/字段/函数/参数等 |
| Go / gopls 0.23.0 | source.organizeImports 生效 | 提取常量、内联调用 |
| Rust / rust-analyzer 0.3.3008 | 未声明/返回标准 source.organizeImports，提示无可用操作、不修改 | 提取变量/常量/static/函数 |
| C/C++ / clangd 22.1.6 | 未声明/返回标准 source.organizeImports，提示无可用操作、不修改 | 交换二元运算符的操作数等；具体候选随位置变化 |

Rust 初始化索引尚未完成时可能返回 ContentModified 或空列表，等待语言服务就绪再操作；不能把一次空列表等同于永久不支持重构。

## 添加新内容指南

### 加插件

在 `lua/plugins/` 下新建 `.lua` 文件，返回 lazy.nvim spec 表即可。

### 加语言支持

1. 如有新文件类型，先在 `core/filetypes.lua` 补识别规则
2. 在 [手动工具清单](</home/pang/.config/nvim/lua/plugins/mason-tool-installer.lua>) 的 ensure_installed 中添加 **Mason 包名**，用 `:MasonToolsInstall` 补齐；不再添加到启动安装列表
3. 在 `lsp/init.lua` 的 `servers` 表里加配置
4. 如需 DAP，在 `lang/` 下新建文件，并在 `lang/init.lua` 里 `require`
5. 如需格式化器，在 `mason-tool-installer.lua` 的 `ensure_installed` 里添加

## Java 回归检查

跨语言补充：[language_actions.lua 测试](</home/pang/.config/nvim/tests/language_actions.lua>) 验证原生动作过滤/选择/应用；[language_servers_smoke.lua](</home/pang/.config/nvim/tests/language_servers_smoke.lua>) 在离线临时项目中启动 Go/Rust/C/C++ 服务，验证导入整理、重构候选和取消不改代码，Rust 会等待索引就绪，退出时只停止自建客户端。

- [java_workflows.lua](</home/pang/.config/nvim/tests/java_workflows.lua>)：真实 Java Treesitter 解析＋模拟客户端/终端，覆盖测试方法定位、内部类转义、终端分配/忙碌/重启、跨项目回调失效。
- [java_terminal_smoke.lua](</home/pang/.config/nvim/tests/java_terminal_smoke.lua>)：真实 toggleterm 临时 shell，验证应用与构建同时运行、只重启指定应用、退出 shell 后保留输出并另建终端。
- [java_jdtls_smoke.lua](</home/pang/.config/nvim/tests/java_jdtls_smoke.lua>)：两个临时 Java 工程和独立 jdtls 工作区，验证主类、Java 路径及 classpath 的真实查询协议，不启动 main。

在配置根目录执行（临时目录每次新建，脚本会停止自己创建的进程，不操作用户项目）：

```bash
T=$(mktemp -d /tmp/nvim-java-check.XXXXXX)
export XDG_STATE_HOME="$T/state" XDG_DATA_HOME="$T/data" XDG_CACHE_HOME="$T/cache"
nvim -u NONE -i NONE -n --headless -l tests/java_workflows.lua
NVIM_JAVA_TEST_TMP="$T/terminals" nvim -u NONE -i NONE -n --headless -l tests/java_terminal_smoke.lua
NVIM_JAVA_TEST_TMP="$T/jdtls" nvim -u NONE -i NONE -n --headless -l tests/java_jdtls_smoke.lua
nvim -u NONE -i NONE -n --headless -l tests/language_actions.lua
nvim -u NONE -i NONE -n --headless -l tests/whichkey_scopes.lua
# 跨语言脚本要求 /tmp/nvim-language- 前缀，且目录内尚无测试工程。
L=$(mktemp -d /tmp/nvim-language-check.XXXXXX)
NVIM_LANGUAGE_TEST_TMP="$L/servers" nvim -u NONE -i NONE -n --headless -l tests/language_servers_smoke.lua
```

## 文档同步规则

修改 Neovim 配置后同步本地文档：

```text
~/md/nvim/nvim命令.md
~/md/nvim/nvim自定义命令.md
~/md/nvim/nvim插件介绍.md
~/md/nvim/nvim配置架构.md
```

- 快捷键速查以 `<leader>hk`（`lua/core/cheatsheet.lua`）为准，本文档只保留「当前快捷键约定」摘要。
- `nvim快捷键.md`、`从零搭建依赖清单.md`、`构建SpringBoot项目实操指南.md` 已于 2026-10-04 删除，不再维护；要查旧内容去 `~/md` 的 git 历史（`git log --diff-filter=D -- nvim/`）。
- `~/md/opencode/opencode配置.md` 也已不存在（opencode 文档已从笔记库移除），涉及 opencode 时不要再往那里写。

当前不再同步 Obsidian 里的旧配置备份，除非用户明确要求。
