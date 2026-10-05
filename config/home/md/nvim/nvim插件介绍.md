# Neovim 插件介绍

> 所有插件通过 lazy.nvim 管理，配置文件在 `lua/plugins/` 下

---

## 主题与外观

### catppuccin/nvim

| 项目 | 说明 |
|------|------|
| **功能** | 主题配色（mocha 风格），覆盖所有插件高亮统一 |
| **配置** | `plugins/theme.lua` |
| **加载** | `lazy = false`, `priority = 1000`（最高优先级，其他插件前加载） |
| **集成** | treesitter、LSP、blink.cmp（`blink_cmp = true`）、snacks、flash、notify、indent-blankline、lualine、noice、DAP、which-key、render_markdown（telescope 集成已随插件删除） |
| **备注** | 透明背景启用；终端透明度由 kitty/Neovide 配置配合；⚠ 2026-09-26 起 `DiagnosticUnnecessary` 被**清空属性**：nvim 0.12 会把带 `unnecessary` tag 的诊断（jdtls 的未使用字段/局部变量/import）整段文字重绘成 `Comment` 灰，而 jdtls 每次编辑后 300~700ms 重新发布 ⇒ 刚写下的字段/常量「变灰再变回来」；清空后文字保持 treesitter 原色，tag 诊断仍有常规严重级别下划线（`DiagnosticDeprecated` 只有删除线、不染字色，未动） |

### nvim-lualine/lualine.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 底部状态栏，显示模式、文件名（含路径）、Git 分支、LSP 诊断、**LSP 客户端状态**、文件类型、进度、光标位置。LSP 客户端那一项是 lualine 自带的 `lsp_status` 组件（2026-09-28 加）：显示已附加的客户端名（`jdtls`/`gopls`…），索引时转圈、就绪显示 `✓`，没有客户端时不占位 |
| **配置** | `plugins/statusline.lua` |
| **加载** | `event = "UIEnter"` |
| **依赖** | catppuccin（主题适配） |
| **备注** | 只有 **alpha 欢迎页**隐藏状态栏；neo-tree 现在**照常显示**（原先它同时写在 `disabled_filetypes` 和 `extensions` 里，两者互斥 ⇒ 切到文件树时整条状态栏空白，2026-09-24 第二轮修掉）；诊断按错误/警告/信息/提示显示对应图标和颜色 |

### akinsho/bufferline.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 顶部标签栏，展示所有打开的缓冲区，支持图标、诊断计数、neo-tree 偏移 |
| **配置** | `plugins/bufferline.lua` |
| **加载** | `event = "VeryLazy"`，也可由 `<S-h>`/`<S-l>` 提前触发 |
| **快捷键** | `<S-h>` 上一个缓冲区、`<S-l>` 下一个缓冲区 |
| **依赖** | nvim-web-devicons、catppuccin |
| **备注** | 2026-09-25 统一调色：`transparent_background=true` 会让 catppuccin 把 bufferline 的 **54 个高亮条目 bg 全写成 NONE**（标签栏=悬浮文字透出壁纸）⇒ 现在包了一层 `highlights` 函数把 bg 补成实底（选中 `base #1e1e2e`、其余 `mantle #181825`，与状态栏一致），分隔符统一 `overlay1 #7f849c`、选中指示条 `blue #89b4fa`、未保存圆点 `yellow #f9e2af`；另加 `always_show_bufferline = false`——**只有一个缓冲区时不画标签栏**，否则启动页/单文件编辑会多出一条**空的**实色横条（透明时代它隐形所以看不出来） |
| **备注** | 标签样式 `thin`，关闭按钮「󰅖」，修改标记「●」，诊断按严重级别显示图标和数量，neo-tree 展开时自动偏移；关闭缓冲区用 `:BufDelete %d`（`core/commands.lua`，内部走 `Snacks.bufdelete`：**保住分屏布局**、未保存时弹确认 —— 原生 `:bdelete` 会把该 buffer 所在的窗口一起关掉） |

### lukas-reineke/indent-blankline.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 缩进位置画竖线，帮助看清代码层级 |
| **配置** | `plugins/indentline.lua` |
| **加载** | `event = "VeryLazy"` |
| **备注** | 竖线字符「│」，作用域高亮关闭（避免太花哨） |

---

## 终端

### akinsho/toggleterm.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 多终端管理器，支持浮动窗口、水平/垂直分屏、多终端实例 |
| **配置** | `plugins/terminal.lua` |
| **加载** | `cmd = "ToggleTerm"`，也可由 `<leader>tt/th/tv` 触发 |
| **快捷键** | `<leader>tt` 浮动终端（terminal id 1；浮窗高度由 toggleterm 算 `min(行数, max(20, 行数-10))`，45 行终端实测 35 行，传进去的 `size` 对 float 无效）、`<leader>th` 水平分割（id 2，15 行）、`<leader>tv` 垂直分割（id 3，宽度自适应 `max(30, min(80, columns*0.45))`：80 列→36，200 列→80） |
| **备注** | 三个键各自绑定独立 terminal id，互不顶替、各自记忆方向与尺寸；复用 keymaps.lua 的终端退出 `jk`；在浮窗里按 `th`/`tv` 会切到分屏并关闭浮窗（toggleterm 在浮窗聚焦时直接建 split 会静默失败）；⚠ 终端模式下按键先送给 shell，**要先 `jk` 回普通模式**再按 |

---

### folke/sidekick.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 在 Neovim 里直接跑 AI CLI（codex / opencode / grok / claude / gemini …）：把「当前文件、光标处、诊断」当上下文发给 CLI（`{this}` / `{file}` / `{diagnostics}`），带预置 prompt 库；当前不使用 mux，AI 改了文件 nvim 自动重载 |
| **配置** | `plugins/sidekick.lua` |
| **加载** | `keys` 懒加载（按 `<leader>aa` 等键才加载） |
| **快捷键** | `<leader>aa` 开关面板、`<leader>as` 选工具（只列已安装的）、`<leader>at` 发送当前上下文（n/x）、`<leader>ad` 断开会话、`<C-.>` 聚焦 CLI 窗口（n/t/i/x） |
| **依赖** | 本机已装 `codex` / `opencode` / `grok`；snacks（可选，更好的选择器）。**不需要 tmux**（`cli.mux` 已关） |
| **备注** | 只启用 CLI，`nes.enabled = false`，不接 Copilot；健康检查前先加载插件，未启用 Copilot LSP 的提示属预期。当前不用 tmux/zellij：`<leader>aa` 调用 toggle，只显示/隐藏终端，不停止 job；`<leader>ad` / `:Sidekick cli close` 走 detach → terminal close，会停止对应终端 job 并清理 buffer。CLI 主题是否需要重启由 CLI 决定，隐藏再显示不保证重读主题。终端真彩色由 `core/options.lua` 在用户未设置时补 `COLORTERM=truecolor`。 |

---
## 文件树与导航

### folke/flash.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 屏幕跳转：按 `s` + 目标字符 → 屏幕上出现标签 → 按标签字母跳到对应位置。比传统 `f/t` 更快，手指不离主行 |
| **配置** | `plugins/flash.lua` |
| **加载** | `event = "VeryLazy"` |
| **快捷键** | `s` Flash 跳转（n/x/o）、`S` Treesitter 选择（n/x/o） |
| **备注** | 覆盖 Vim 默认 `s`（删除字符进入插入模式），用户不需要默认行为 |

### nvim-neo-tree/neo-tree.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 左侧文件树，显示项目文件结构，支持 Git 状态图标、文件监听自动刷新 |
| **配置** | `plugins/filetree.lua` |
| **加载** | `cmd = "Neotree"` |
| **快捷键** | `<leader>e` 打开/关闭 |
| **依赖** | plenary.nvim、nui.nvim、nvim-web-devicons |
| **文件树内快捷键** | `h` 上级目录、`l` 设为根目录、`r` 重命名、`m` 移动、`c` 复制、`y` 复制到剪贴板、`x` 剪切、`p` 粘贴、`H` 显示/隐藏隐藏文件（原先 `p` 被拿去当"显示隐藏文件"，顶掉了默认的粘贴，2026-09-25 已修） |
| **备注** | 默认 `follow_current_file` 跟踪当前文件，`bind_to_cwd = true` 跟随 CWD；从项目列表选中项目后，文件树根目录会同步到该项目；`use_popups_for_input = false` 把输入委托给 `vim.ui.input`，由 snacks 输入框统一渲染；宽度改为函数自适应 `max(20, min(35, floor(columns*0.4)))`（80 列→32，60 列→24，200 列→35） |

> **搜索已全部改由 snacks picker 提供**（`<leader>ff/fg/fb/fh/fc/fp`），telescope.nvim 及其 spec、磁盘文件均已删除（`:Lazy! clean` 清理，`lazy-lock.json` 不再引用）。详见下文 snacks 小节。

### ahmedkhalf/project.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 项目管理，通过 `.git`、CMake、Node、Go、Rust、Maven、Gradle 等标记自动检测项目根目录；本机只保留它的**项目历史**，选择器换成 snacks picker |
| **配置** | `plugins/project.lua` |
| **加载** | `lazy = false`，启动即初始化项目历史，保证启动页第一次打开项目列表就有内容 |
| **快捷键** | `<leader>fp` 通过 `:Projects` 浏览项目 |
| **备注** | 保留 `vim.lsp.get_clients()` 兼容补丁和切项目后刷新 neo-tree。`core/projects.lua` 集中 `:Projects`、同步读取和 `DirChanged`：只追加副本 + 历史并集 + append 回填，再加 `plugins/project.lua` 的只追加写守卫，共四层保护。上游异步读配合截断写可能丢历史，因此守卫永不调用截断写，异常也不回退截断；并发重复行在读取端去重。 |

---

## 代码补全与 LSP

### saghen/blink.cmp

| 项目 | 说明 |
|------|------|
| **功能** | 代码补全引擎，替代 nvim-cmp。支持 LSP、代码片段、缓冲区内容、路径补全 |
| **配置** | `plugins/completion.lua` |
| **加载** | `lazy = false`（立即加载，确保补全始终可用） |
| **快捷键** | `<CR>` 选中当前项、`<C-n>`/`<C-p>` 上下选择、`<C-u>`/`<C-d>` 文档翻页、`<C-e>` 关闭（这三个键已补 `fallback`，菜单未打开时恢复插入模式内置行为）；`<Tab>` 进插入模式后由 neotab 接管（跳括号/引号外侧），`<Shift-Tab>` 跳上一个片段占位符 |
| **补全来源** | lsp、snippets、buffer、path |
| **备注** | 使用 Neovim 原生 `vim.snippet`，自动读取 friendly-snippets；catppuccin 直接启用 `blink_cmp` 集成；`<Tab>` 实测不接手补全确认（被 neotab 先接管），选中补全项用 `Enter`；补全文档窗 `auto_show_delay_ms = 800`、`max_height = 12`、`desired_min_width = 40`（避免一停就弹、行数过高挡代码） |

### neovim/nvim-lspconfig

| 项目 | 说明 |
|------|------|
| **功能** | LSP 客户端配置框架，管理 clangd、lua_ls、jdtls、gopls、rust_analyzer、html、cssls、jsonls、yamlls、marksman 等语言服务器 |
| **配置** | `plugins/lsp/init.lua` |
| **加载** | `lazy = false` |
| **依赖** | mason.nvim、blink.cmp、lazydev.nvim（`ft = "lua"`，2026-09-28 加：给 lua_ls 提供 Neovim 环境类型，见 `nvim配置架构.md` 的 A01 行） |
| **快捷键** | `gd` 跳转定义、`gR` 类型定义、`gi` 实现、`gh` 悬停文档、`grr`/`gra`/`grn`/`gri`/`grt`（0.12 内置 `gr` 前缀：引用/代码操作/重命名/实现/类型定义）、`[d`/`]d` 诊断导航、`<leader>rn` 重命名、`<leader>ca` 所有代码操作、`<leader>Ra` 可用重构列表（普通/可视）、`<leader>ot` 按语言整理导入、`<C-k>` 签名提示 |
| **备注** | jdtls 跳过（由 nvim-jdtls 管理）。使用 Neovim 0.12 新 API `vim.lsp.config()` 注册；`[d`/`]d` 使用 `vim.diagnostic.jump` |

### williamboman/mason.nvim

| 项目 | 说明 |
|------|------|
| **功能** | LSP 服务器、格式化工具、调试器安装管理器：`:Mason` 打开界面安装 |
| **配置** | `plugins/mason.lua` |
| **加载** | `lazy = false`，启动时先 setup；`:Mason` 打开管理界面 |
| **依赖** | mason-tool-installer.nvim（手动工具清单包含所有已配置 LSP，启动不执行检查） |

### williamboman/mason-lspconfig.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 提供 LSP 名称与 Mason 包名映射，保留手动 `:LspInstall` / `:LspUninstall` |
| **配置** | [mason-lspconfig.lua](</home/pang/.config/nvim/lua/plugins/mason-lspconfig.lua>)，不再放在启动 LSP 的依赖链中 |
| **加载** | 只由 `LspInstall` / `LspUninstall` 命令加载；Mason 依赖先初始化 |
| **备注** | `automatic_enable = false`、`ensure_installed = {}`；调用手动安装命令不会顺带安装全部服务器。批量补齐改用 `:MasonToolsInstall` 的完整 Mason 包名清单，并关闭安装器的 mason-lspconfig 别名集成，防止启动时隐式加载。 |

### WhoIsSethDaniel/mason-tool-installer.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 手动批量补齐/更新已配置的 LSP、调试器和格式化工具 |
| **配置** | [mason-tool-installer.lua](</home/pang/.config/nvim/lua/plugins/mason-tool-installer.lua>)，清单使用 Mason 包名 |
| **加载** | 随 Mason 加载并注册命令，但 run_on_start=false，不在启动时检查或安装 |
| **手动入口** | `:MasonToolsInstall` 补齐、`:MasonToolsUpdate` 更新；包括原有调试/格式化工具和迁入的全部 LSP |
| **集成** | 关闭 mason-lspconfig 别名集成，避免隐式 require 触发启动刷新；LSP 名称安装仍可用独立的 `:LspInstall` |

### rafamadriz/friendly-snippets

| 项目 | 说明 |
|------|------|
| **功能** | 为常用语言提供现成代码片段，由 blink.cmp 内置 snippets source 读取 |
| **配置** | 作为 `plugins/completion.lua` 的依赖；片段展开和占位符跳转使用 Neovim 原生 `vim.snippet` |
| **加载** | 随 blink.cmp 加载 |
| **备注** | 替代未实际接入 Blink、也没有片段定义的 LuaSnip 空配置，减少无效插件逻辑 |

---

## 界面增强

### folke/noice.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 命令行美化：按 `:` 弹出居中浮动输入框（`width = "auto"` —— noice 只在 auto 时才把宽度夹进 minmax(min_width, max_width = `columns-4`, 内容宽)）；`min_width` 由 `core/input_boxes.lua` 按屏幕列数算（`noice_min_width = clamp(columns − 6, 30, 80) − 4`），与 snacks 输入框**等长**、内容行重合，长命令仍随内容变宽；`vim.fn.input` 的浮窗标题显示为「 输入 」；通知消息和 LSP 进度提示。⚠ 2026-09-28（审查 U01）实测修正：盒模型偏移是 **4 不是 2**（114 列下 `min_width=78` ⇒ 外框 82、80 列下 72 ⇒ 76），旧实现少减 2 列 ⇒ 两个框一直差 2 列；宽度也不再写死 80（旧配置在 80 列终端外框 82，右边框被屏幕裁掉）。⚠ noice 的 `min_width` 只能是**数字** ⇒ 这是配置加载时的快照，改终端大小要重启才跟上（snacks 那侧是开窗时求值的函数） |
| **配置** | `plugins/noice.lua` |
| **加载** | `lazy = false` |
| **依赖** | nui.nvim、nvim-notify |
| **备注** | `vim.notify` 先由 nvim-notify 接管（启动期避免 noice 的 notify view 缺依赖），noice 在 `VimEnter` 后加载时再接管一次——所以 LSP/插件报错只闪一次通知、`:messages` 里查不到，改用 `<leader>he`/`<leader>hh` 看 noice 历史；过滤了搜索计数和 jdtls 进度的冗余通知；补全菜单后端用 nui 渲染；`vim.ui.select`/`vim.ui.input` 现在统一由 snacks 提供（noice 只负责命令行与通知，两者不再协作渲染输入框） |

> dressing.nvim 已随 UI 收敛删除（spec 与磁盘文件都不在），`vim.ui.select`/`vim.ui.input` 改由 snacks 接管。

### goolord/alpha-nvim

| 项目 | 说明 |
|------|------|
| **功能** | 启动欢迎页，显示 NEovIM ASCII 艺术字 Logo 和快捷按钮 |
| **配置** | `plugins/dashboard.lua` |
| **加载** | 仅无文件参数时由 `VimEnter` 自动加载；有文件启动时不抢首屏，但 `:Alpha` / `:A` 仍可按需加载 |
| **快捷键** | `f` 查找文件、`r` 最近文件、`c` 打开 Neovim 配置、`p` 项目列表、`n` 新建文件、`q` 退出 |
| **备注** | `columns >= 58` 才显示完整 ASCII Logo（logo 实测宽 52 列），否则退化为纯文字「NEOVIM」；页脚 `columns >= 80` 显示完整 cwd，否则只显示目录名，避免裁切；配色走的是 catppuccin 通用组：页脚 `Type`、按钮文字 `Label`、快捷键 `Keyword`（见 `plugins/dashboard.lua` 的 `dashboard.section.*.opts.hl`）。⚠ 早期文档里写的 `AlphaDashHeader`/`AlphaDashButton`/`AlphaDashShortcut`/`AlphaDashFooter` 这套自定义组**在当前实现里并不存在**（2026-09-25 审查 F17 核对：`grep -rn AlphaDash lua/` 为 0 处），别照着它找高亮 |

### folke/which-key.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 快捷键提示：按 `<leader>`（或 `\`）后弹出浮动窗口，显示该前缀下所有快捷键 |
| **配置** | `plugins/whichkey.lua`（`triggers` = `<leader>` / `\` / `g` / `z` / `[` / `]` / `<C-w>`，且**普通模式与可视模式都生效**（`mode = { "n", "v" }`；2026-09-25 修：此前只写了 `"n"`，导致 Java 缓冲区可视模式下按 `<leader>` 无提示）。**2026-09-25 两次修**：先因用户反馈「按 g 想看看定义/引用，按下去毫无反应」加上 `g`（用**显式触发器**，不是 `<auto>`），随后全面复查发现 `z`/`[`/`]`/`<C-w>` 是**同一类**（spec 都有、触发器都没含）⇒ 一并加上。**有意不加**：操作符后的 motion（`w/b/0/$/gg/G…`）与文本对象 `a`/`i`（`aw`/`i(` 序列会打扰；需要时 `:WhichKey a`）。`delay = 300`，快速连打 `gg`/`zz` 不闪。`gr*` 是 0.12 内置 LSP 键（`grr` 引用 / `grn` 重命名 / `gra` 代码操作 / `gri` 实现 / `grt` 类型定义），本配置故意不覆盖 `gr` 前缀，并在 which-key spec 里补了中文说明） |
| **加载** | `event = "VeryLazy"`，`delay = 300`（按前缀后 300ms 才弹） |
| **备注** | 菜单按用途加前缀（2026-10-04）：`通用` 为文件/窗口/搜索/终端/AI 等；`LSP` 为代码操作与重命名；`DAP` 为跨语言调试（需对应调试器）；`整理 · 按语言` 为 o、`重构 · 按语言` 为 R，`Java` 为 G/J/m；`Spring`、`Markdown`、`Neovide` 各有明确适用范围。o/R 下既有通用入口 ot/Ra，也保留只在 Java 中提供的 Rv/Rc/Rm/RV；直接提取项明确标 Java。分组名称覆盖普通与可视模式，触发器不变（本次另新增通用 Ra，扩展 ot）；无子项空组由 which-key 自动隐藏。sp、Java 代码生成等全局创建入口仍保留，不能把“功能专用”误当成“只在该文件里能按”。窗口切分仍在 v，不在 s。 |

### folke/snacks.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 统一提供搜索/选择器与 `vim.ui.input` 输入框；Noice 仍负责命令行和消息，Alpha 负责欢迎页。输入框与 Noice 共用 `core/input_boxes.lua` 的尺寸策略，但 Noice 最小宽度仅在加载时求值，且两种边框位置仍可能差一行，不保证 resize 后完全等宽等高。 |
| **配置** | `plugins/snacks.lua` 配置 picker/input，从默认键位拷贝后追加映射；调用 `core.ui.setup()` 统一皮肤。普通 picker 和 `vim.ui.select` 使用 `picker_compact`；grep 单独构造列表/预览布局，不对 select 的布局数组做深合并，避免残留旧节点。 |
| **布局** | grep（`<leader>fg`）在宽屏（≥120 列）使用左侧输入/列表、右侧预览，窄屏改为上方输入/列表、下方预览。其他 picker 继续紧凑且默认无预览，原有键位不变。 |
| **加载** | `lazy = false`，`priority = 1000`；`vim.ui.select`/`vim.ui.input` 在 **UIEnter** 时正式接管（headless 测不到，真 TTY 实测来源为 `snacks/picker/init.lua`、`snacks/input.lua`） |
| **快捷键** | picker 内：`<CR>` 确认、`<Tab>`/`<S-Tab>` 多选切换、`<Esc>` 一次关闭、方向键上下；另追加 `<C-j>`/`<C-k>` 与 `<C-n>`/`<C-p>` 上下移动 |
| **皮肤** | `core/ui.lua` 集中 soft/pink 色板、高亮、`:PickerSkin` 和 `ColorScheme` 重设；默认 soft，`:PickerSkin soft` / `:PickerSkin pink` 即时切换。Spring 向导读取同一色板，不另写共享高亮。标题、边框和选中行需覆盖 snacks 实际使用的组（如 `SnacksTitle`、`SnacksPickerBoxBorder`、`SnacksPickerListCursorLine`），避免主题默认色漏出。 |
| **行渲染** | picker 的 `format = function(item, picker)` 支持 chunk 数组 `{ {文本, 高亮组}, ... }`，可做图标列/多色排版（`:Projects` 就是"蓝色文件夹图标 + 项目名亮色 + 父目录灰色"）；snacks 会在**渲染后的文本**上重算匹配高亮，`resolve = function(max_width)` 的 chunk 能做宽度感知截断 |
| **备注** | 除 `picker`/`input` 外**全部显式关闭**（notifier 会顶掉 noice、dashboard 顶掉 alpha、terminal 顶掉 toggleterm 等）；⚠ **坑：snacks 对 `win.*.keys` 是整体替换语义**——只写几个键会把默认的 `<CR>`/`<Tab>`/`<Esc>` 一起干掉（实测向导按 CR 不确认、picker 关不掉），必须从 defaults 拷贝再 merge，且要放在 `config()` 里（spec 解析期 snacks 还没进 rtp）；picker 同 `source` 会互相 dedupe，故向导用 `spring-wizard`/`spring-wizard-deps`、jdtls 多选用 `jdtls-pick-many`、项目列表用 `project-history`（**不能**用内置同名源 `projects`） |

### MeanderingProgrammer/render-markdown.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 直接美化原 Markdown 编辑区的标题、列表、引用、表格、链接和代码块，不打开浏览器或独立预览窗口，不改写文件内容 |
| **配置** | `lua/plugins/markdown.lua`；`ft = "markdown"`，Markdown FileType 自动加载 |
| **模式** | 普通/命令模式渲染，插入/可视模式回到源码；光标行启用 anti_conceal，方便看清并修改标记 |
| **透明主题** | 标题 `heading.backgrounds = {}`；代码块 `disable_background = true`、`style = "language"`、`border = "none"`，禁用 sign；避免整行底色和额外边框。catppuccin 启用 `render_markdown` 集成 |
| **依赖** | 复用现有 nvim-treesitter 与 nvim-web-devicons；LaTeX 暂不启用，不额外安装转换工具；不承诺浏览器级图片、Mermaid 或 LaTeX 渲染 |
| **快捷键** | `<leader>Mp` 仅切换当前缓冲区美化；旧 `<leader>Mt` / `<leader>Ms` 移除 |
| **命令** | `:RenderMarkdown buf_toggle` / `buf_enable` / `buf_disable` 仅作用于当前缓冲区；`enable` / `disable` / `toggle` 是全局操作。旧 `:MdRender` 不再使用 |
| **历史取舍** | 2026-09-25 曾依次尝试 render-markdown（代码块整行底色在透明主题下像“斑马带”，用户：“看着好怪”）、markview（关底色后仍反馈“终端渲染好像都不太行”）、markdown-preview.nvim（浏览器预览，要下 45MB 预编译二进制），当时最终选了 md-render 独立窗口。这些是当时反馈，不代表就地渲染必须放弃；本次用户明确不喜欢 md-render，并选择“直接美化编辑区”，因此改用上述无整块底色方案。新方案观感仍需用户确认 |

---

## 编辑辅助

### windwp/nvim-autopairs

| 项目 | 说明 |
|------|------|
| **功能** | 自动补全括号：输入 `(` 自动加 `)`，输入 `{` 自动加 `}`，以此类推 |
| **配置** | `plugins/autopairs.lua` |
| **加载** | `event = "InsertEnter"` |
| **备注** | 使用默认配置 |

### kawre/neotab.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 按 Tab 跳出括号/引号：当光标在 `]`、`)`、`}`、`'`、`"`、`` ` ``、`>` 等配对符内时，Tab 直接跳出而非输入空格 |
| **配置** | `plugins/neotab.lua` |
| **加载** | `event = "InsertEnter"` |
| **备注** | `act_as_tab = true` 保证无补全时 Tab 正常输入空格；进入插入模式后 `<Tab>` 由 neotab 接管——括号/引号内跳到外侧，实测**不是**接受补全（接受补全用 `Enter`） |

### nvim-zh/better-escape.vim

| 项目 | 说明 |
|------|------|
| **功能** | 用 `jk` 快速退出插入模式，不依赖 timeoutlen，无延迟感 |
| **配置** | `plugins/betterescape.lua` |
| **加载** | `event = "InsertEnter"` |
| **备注** | 间隔 200ms，比默认 timeoutlen 方案响应更快 |

### 注释（Neovim 内置，无插件）

| 项目 | 说明 |
|------|------|
| **功能** | `gcc` 注释/取消注释当前行，`gc` 注释/取消注释选中区域（**Neovim 0.10+ 内置**，本机 0.12.5 默认映射见 `vim/_core/defaults.lua`） |
| **配置** | 无（不需要配置文件）；原先的 `plugins/comment.lua`（numToStr/Comment.nvim，停更 27 个月）已于 2026-09-24 第二轮删除并 `:Lazy! clean` |
| **注意** | 内置**只有** `gc` / `gcc` / operator-pending 的 `gc` 文本对象；**没有** `gb`/`gbc`（块注释）与 `gcO`/`gco`/`gcA`——这些是 Comment.nvim 的额外映射，本配置从未使用。`commentstring` 与 treesitter 的 capture 元数据都会被内置注释识别（Java/Lua/YAML 均已实测） |
| **历史坑** | 旧 spec 的 `keys = { "gc" }` 是 lazy 桩映射，会**顶掉内置 gc**；删掉插件后内置映射自动接管 |

### nvim-treesitter/nvim-treesitter

| 项目 | 说明 |
|------|------|
| **功能** | Treesitter 语法解析器，提供精确的语法高亮、代码折叠、智能缩进 |
| **配置** | `plugins/treesitter.lua` |
| **加载** | `lazy = false`（新版 nvim-treesitter 不支持 lazy-loading）+ `cmd = { "TSInstall", "TSUpdate", "TSConfigInfo" }` |
| **备注** | 自动安装未安装的语言解析器，安装前兼容 Mason CLI 加载时序；清单包括 bash、c/cpp、css、go、html、java、javascript、json、lua、markdown、rust、vim、yaml，以及 2026-09-24 补上的前端五项 **typescript / tsx / vue / svelte / scss**（`.ts`/`.tsx`/`.vue`/`.svelte`/`.scss` 的高亮与缩进）；nvim-treesitter 自带 filetype→parser 别名注册（tsx↔typescriptreact、json↔jsonc、bash↔sh 等），不需要手写 `vim.treesitter.language.register`。⚠ 本机 GitHub 需走 Clash 代理（`127.0.0.1:7890`）：代理没开时解析器装不上，故缺失时的自动下载加了 **6 小时节流**，避免每次启动都刷一屏 curl 报错 |

---

## 调试

### mfussenegger/nvim-dap

| 项目 | 说明 |
|------|------|
| **功能** | DAP（调试适配器协议）客户端，配合 codelldb 调试 C/C++/Rust、delve 调试 Go、jdtls 调试 Java |
| **配置** | `plugins/dap/init.lua` |
| **加载** | 本配置通过 DAP 快捷键按需加载，并由 `ensure_java_dap()` 在 Java 调试入口完成接线；上游 nvim-jdtls 的附加钩子也可能加载 DAP，因此不承诺打开 Java 后绝无 DAP 模块。 |
| **依赖** | nvim-dap-ui（调试界面）、nvim-nio（异步 IO）、nvim-dap-virtual-text（行内变量值） |
| **快捷键** | `<leader>dl` 重跑上次调试、`<leader>db` 断点列表、`<leader>dB` 条件断点、`<leader>dL` 日志断点、`<leader>dC` 清除所有断点、`<F5>` 继续、`<F9>` 切换断点、`<F10>` 单步跳过、`<F11>` 单步进入、`<F12>` 单步跳出 |
| **备注** | 调试 UI 放右侧（避免和左侧 neo-tree 冲突）；侧栏宽 `max(28, min(45, floor(columns*0.32)))`（80 列→28，200 列→45），底部 REPL 10 行；调试开始自动打开 UI，结束自动关闭；断点符号改用 Nerd Font 图标；`<leader>dB`/`<leader>dL` 在输入为空（Esc 取消）时**不建断点**并提示——2026-09-25 用原始 `setBreakpoints` 报文实测：空的 logMessage/condition/hitCondition 上游**不报错**，而是退化成**普通断点**（真 JVM 里会真的停住），所以不能让它悄悄建出来 |

### rcarriga/nvim-dap-ui

| 项目 | 说明 |
|------|------|
| **功能** | DAP 图形界面：右侧面板显示变量、断点、堆栈、监视，底部显示 REPL 和日志；侧栏宽度自适应 `max(28, min(45, floor(columns*0.32)))` |
| **配置** | 作为 dap 依赖，在 `plugins/dap/init.lua` 中配置布局 |
| **加载** | 作为 dap 的依赖自动加载 |

### nvim-neotest/nvim-nio

| 项目 | 说明 |
|------|------|
| **功能** | 异步 IO 库，nvim-dap-ui 的依赖 |
| **配置** | 作为 dap 的依赖 |
| **加载** | 作为 dap 的依赖自动加载 |

### theHamsta/nvim-dap-virtual-text

| 项目 | 说明 |
|------|------|
| **功能** | 调试时在行尾显示变量值，无需切换到 scopes 面板 |
| **配置** | 作为 dap 依赖，`opts.all_frames = true` 显示所有栈帧，`virt_text_pos = "eol"` 放行尾 |
| **加载** | 作为 dap 的依赖自动加载 |

---

## 代码格式化

### stevearc/conform.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 代码格式化引擎，保存文件时自动格式化（**Java 除外**，见备注），也支持手动触发 |
| **配置** | `plugins/format.lua` |
| **加载** | `event = { "BufWritePre" }`，并保留 `<leader>F` 手动触发 |
| **快捷键** | `<leader>F` 手动格式化 |
| **支持的格式工具** | stylua（lua，2 格）、google-java-format（java，4 格，`--aosp`）、clang-format（c/cpp，4 格）、rustfmt（rust，4 格） |
| **格式化器配置文件** | `~/.clang-format`（clang-format） |
| **备注** | `format_on_save.timeout_ms = 2000` 超时保护；`lsp_format = "fallback"` 优先使用可用的 CLI formatter；没有可用 CLI formatter 且有支持格式化的 LSP 时回退，登记了但缺少工具也不阻止回退（CLI 执行报错不等于自动改用 LSP）；**Java 保存时不自动格式化**（`filetype == "java"` 有意跳过：半成品代码常无法被 google-java-format 解析），需要时手动 `<leader>F`；Lua 跟随 `stylua.toml` 使用 2 格，其余常用语言使用 4 格 |

---

## 语言专用

### mfussenegger/nvim-jdtls

| 项目 | 说明 |
|------|------|
| **功能** | Java 语言服务器增强（Eclipse JDTLS），提供代码补全、调试、重构等完整 Java 开发体验 |
| **配置** | `plugins/lang/java.lua` |
| **加载** | `ft = { "java" }`（打开 Java 文件时加载） |
| **快捷键** | `<F5>` 调试当前 Java 项目（每次查询主类，已有会话则继续）；`<leader>Jd` 重新查询当前项目主类；`<leader>Jt` / `<leader>JT` 在终端运行测试方法 / 测试类；`<leader>Jg` / `<leader>JG` 调试测试方法 / 测试类；`<leader>sr` 运行 Spring Boot 项目（自动识别主类，多个入口弹选择框、含「全部启动」，每个主类一个终端，已在跑的标 `●`）；`<leader>co` Java 代码操作；`<leader>ot` 通过通用入口调用 jdtls 整理 import；`<leader>Ra` 通用重构列表，Rv/Rc/Rm/RV 仍为 Java 增强；`gA` 跳转父类/接口实现（原 `gU`，让位给内置转大写） |
| **依赖** | nvim-dap（调试）、mason 安装的 jdtls 和 java-debug-adapter |
| **备注** | lspconfig 已跳过 jdtls（由本插件接管）；由 `java.lua` 注入 java-debug/java-test 的 OSGi bundles，并排除 test runner、jacoco 和 JDTLS 已提供的重复 ASM bundle；工作区目录按项目分开存储，避免互相污染；⚠ 2026-09-26 起**按 buffer 关闭 Java 的 LSP 语义高亮**（`java_on_attach` 里 `vim.lsp.semantic_tokens.enable(false, { bufnr = bufnr })`）：nvim 0.12 会自动启用服务器支持的 capability，jdtls 的语义 token（优先级 125）盖过 treesitter（100）——实测同一常量在编辑后从 `@constant.java` teal 跳成 `@lsp.type.property` lavender，正是用户报的「写 Java 时颜色变来变去」；关掉后 Java 仍由 treesitter 完整高亮；⚠ `<leader>sr` 的扫描与参数逻辑在 `core/java_main.lua`（纯逻辑、可 headless 断言）：多入口项目盲跑 `spring-boot:run` 会报 `Unable to find a single main class`，终端槽与「全部启动」的细节见 `nvim配置架构.md` 的「特殊处理」 |

Java 工作流辅助模块（2026-10-04）：
- [java_test.lua](</home/pang/.config/nvim/lua/core/java_test.lua>) 用 Treesitter 定位当前方法；不再向上猜，成员内部类的 `$` 会被 shell 转义。
- [java_terminals.lua](</home/pang/.config/nvim/lua/core/java_terminals.lua>) 按项目＋用途＋主类分配专用终端，从 4 起避开占用编号；测试不挤进应用输入，忙碌构建不叠加，应用重启等待旧进程退出。通用 1/2/3 不变，重开应用终端用通知里的编号，如 `:4ToggleTerm`。
- [java_debug.lua](</home/pang/.config/nvim/lua/core/java_debug.lua>) 只向捕获的当前 jdtls 客户端查询，不读写全局 DAP 主类列表；错误、超时、过时回调都有出口。

### JavaHello/spring-boot.nvim + elmcgill/springboot-nvim

| 项目 | 说明 |
|------|------|
| **功能** | Spring Boot 支持：`application.yml`/`.properties` 的 Spring 属性补全、诊断、跳转和 Code Action；Java 的类/接口/枚举/Record 生成、增量编译与项目向导 |
| **配置** | `plugins/lang/springboot.lua`（由 `plugins/lang/init.lua` 聚合加载） |
| **加载** | `spring-boot.nvim`：`cmd = { "SpringBoot" }` + `ft = { "java", "yaml", "jproperties" }`；`springboot-nvim`：只声明 `ft = { "java" }`（第二轮把 `lazy = false` 去掉了：它让 `ft` 变死配置，还把 nvim-jdtls/DAP 拖进启动期。2026-09-25 又移除了 `cmd = { "SpringBootNewProject" }` 桩——原版向导已不推荐，用不到启动期注册） |
| **快捷键** | `<leader>sp` 项目向导（可搜索选择）、`<leader>Gc/Gi/Ge/Gr` 生成 Class/Interface/Enum/Record（`<leader>sP` 原版向导 2026-09-25 已删：Boot 4 版本号有 bug） |
| **依赖** | nvim-jdtls、nvim-lspconfig、mason 安装的 `vscode-spring-boot-tools` |
| **备注** | 复用现有 jdtls，不替换 Java 启动配置；`<leader>sp` 注册在 spec 的 `keys` 上，是**全局键**（任何缓冲区可用，不限 java/yaml）；`:SpringBootCreate` 由 `core/spring_wizard.lua` 在 core 层注册，保证刚启动就能用。⚠ **运行**入口 `<leader>sr` 不在本文件：它是 `plugins/lang/java.lua` 注册的 **Java 缓冲区本地键**（自动识别主类、每个入口一个终端），本文件只管补全 / 类生成 / 向导 |

## C/C++ 语言附加配置

### plugins/lang/cpp.lua

| 项目 | 说明 |
|------|------|
| **配置位置** | `plugins/lang/cpp.lua`（通过 `lang/init.lua` 聚合加载） |
| **clangd 参数** | `--background-index`（后台索引）、`--clang-tidy`（启用 clang-tidy 检查）、`--completion-style=detailed`、`--header-insertion=iwyu` |
| **codelldb 调试** | 通过 mason 安装 codelldb，配置为 server 类型，端口动态分配 |
| **备注** | clangd 的 `opts.servers.clangd` 扩展了 `lsp/init.lua` 中的基础配置；显式固定 filetypes 为 `c/cpp/objc/objcpp/cuda/proto`，避免 `c.doxygen/cpp.doxygen` health warning；DAP 配置含 `cpp`（3 种）、`c`（2 种） |

### Rust 语言（plugins/lang/rust.lua）

Rust 的 LSP 配置在 `lsp/init.lua`（基础）和 `lang/rust.lua`（扩展）中，DAP 配置在 `lang/rust.lua` 中（复用 codelldb 适配器），格式化器 rustfmt 来自 rustup 管理的 stable 工具链。

| 项目 | 说明 |
|------|------|
| **LSP** | `rust_analyzer` 通过 `:MasonToolsInstall` 或 `:LspInstall rust_analyzer` 手动安装，配置在 `lsp/init.lua` `opts.servers.rust_analyzer` |
| **DAP** | 复用 codelldb（`cpp.lua` 定义适配器），`lang/rust.lua` 中配置 `rust` 类型（启动调试取 `target/debug/` 路径 + attach） |
| **格式化** | `rustfmt` 由 rustup component 提供，`format.lua` 中配置 `formatters_by_ft.rust` |
| **前置** | Arch 上安装 `rustup` 包，执行 `rustup default stable`，再安装 `rust-src rustfmt clippy` |
| **备注** | `rust_analyzer` 仅在 `rustc` 和 `cargo` 可用时启用；当前 `rustc --print sysroot` 指向 `~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu`；检查命令使用 `check.command = "clippy"` |

### plugins/lang/go.lua

| 项目 | 说明 |
|------|------|
| **配置位置** | `plugins/lang/go.lua`（通过 `lang/init.lua` 聚合加载） |
| **gopls LSP** | 通过 `:MasonToolsInstall` 或 `:LspInstall gopls` 手动安装，启用 gofumpt、unusedparams、unreachable 分析、staticcheck |
| **delve 调试** | 通过 mason 自动安装 `delve`，配置为 server 类型；单配置 `启动调试`，自动编译运行当前 package |
| **快捷键** | 复用 DAP 全局快捷键（`<F5>` 启动、`<F9>` 断点等） |

---

## 依赖库

### nvim-tree/nvim-web-devicons

| 项目 | 说明 |
|------|------|
| **功能** | 文件类型图标，被 bufferline、neo-tree、snacks picker 等共用 |
| **配置** | `plugins/devicons.lua`：用 `opts.override` 补齐 `application.properties`（齿轮 U+E615）与 `*.gotmpl`（Go 图标 U+E627）的图标，避免 neo-tree/bufferline 退化成默认图标 |
| **备注** | 字形刻意复用字体里已有的码点，不掉方块；其余情况仍作为其它插件的依赖自动引入 |

### nvim-lua/plenary.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 通用工具库，提供异步 IO、文件操作、字符串处理等基础功能 |
| **配置** | 不单独配置，现在作为 neo-tree 的依赖保留（telescope 已删除，plenary 因 neo-tree 不能一起删） |

### MunifTanjim/nui.nvim

| 项目 | 说明 |
|------|------|
| **功能** | UI 组件库，提供浮动窗口、输入框等底层组件 |
| **配置** | 不单独配置，作为 noice、neo-tree 等插件的依赖引入 |

---

## 配置文件对应关系

| 配置文件 | 用途 / 对应插件 |
|----------|------------------|
| `plugins/autopairs.lua` | nvim-autopairs |
| `plugins/betterescape.lua` | better-escape.vim |
| `plugins/bufferline.lua` | bufferline.nvim |
| `plugins/completion.lua` | blink.cmp |
| `plugins/dashboard.lua` | alpha-nvim |
| `plugins/devicons.lua` | nvim-web-devicons 图标补齐（application.properties、*.gotmpl） |
| `plugins/filetree.lua` | neo-tree.nvim |
| `plugins/flash.lua` | flash.nvim |
| `plugins/format.lua` | conform.nvim |
| `core/filetypes.lua` | 自定义 filetype 识别 |
| `core/lsp_on_attach.lua` | LSP `on_attach` 的通用键位与诊断（lspconfig 与 jdtls 共用） |
| `core/java_main.lua` | Java 主类扫描 + `spring-boot:run` / `bootRun` 主类参数（`<leader>sr` 的纯逻辑层） |
| `core/spring_wizard.lua` | Spring Boot 项目向导（11 步；`:SpringBootCreate` / `<leader>sp` 的实现） |
| `plugins/indentline.lua` | indent-blankline.nvim |
| `plugins/mason.lua` | mason.nvim |
| `plugins/mason-tool-installer.lua` | mason-tool-installer.nvim（作为 mason 的依赖随启动期加载 —— 2026-09-25 审查确认旧写的 `event = "VeryLazy"` 是死触发器，已删；`run_on_start = false`，自动补装 codelldb / java-debug-adapter / java-test / lemminx / vscode-spring-boot-tools / delve / stylua / google-java-format / clang-format / tree-sitter-cli） |
| `plugins/neotab.lua` | neotab.nvim |
| `plugins/noice.lua` | noice.nvim |
| `plugins/project.lua` | project.nvim |
| `plugins/markdown.lua` | render-markdown.nvim（原编辑窗口内美化，`<leader>Mp` 仅切换当前缓冲区） |
| `plugins/snacks.lua` | snacks.nvim（picker + input，全机唯一 UI 提供者） |
| `plugins/statusline.lua` | lualine.nvim |
| `plugins/terminal.lua` | toggleterm.nvim |
| `plugins/theme.lua` | catppuccin/nvim |
| `plugins/treesitter.lua` | nvim-treesitter |
| `plugins/whichkey.lua` | which-key.nvim |
| `plugins/dap/init.lua` | nvim-dap + nvim-dap-ui + nvim-nio |
| `plugins/lsp/init.lua` | nvim-lspconfig，管理已安装语言服务的启动 |
| [mason-lspconfig.lua](</home/pang/.config/nvim/lua/plugins/mason-lspconfig.lua>) | 按命令加载的手动 LSP 安装入口 |
| `plugins/lang/init.lua` | 语言配置聚合入口 |
| `plugins/lang/cpp.lua` | clangd 扩展 + codelldb DAP |
| `plugins/lang/java.lua` | nvim-jdtls + Java DAP |
| `plugins/lang/go.lua` | gopls + delve DAP |
| `plugins/lang/rust.lua` | rust_analyzer 扩展 + codelldb Rust DAP |
| `plugins/lang/springboot.lua` | Spring Boot 补全 / 类生成 / 向导 |

---

> **历史记录（本次 Markdown 替换前）**：插件总数 38 个（`~/.local/share/nvim/lazy/` 实际安装目录数，含 lazy.nvim 本身），`lazy-lock.json` 条目数已与之一致。2026-10-04 跑了一次 `:Lazy update`：把 2026-09-28 加入却一直没被写进锁文件的 **lazydev.nvim**（`ft = "lua"`，见 lspconfig 小节的依赖）补上（旧锁文件停在 2026-09-25，只有 37 条），同批 5 个插件升到最新 —— `nvim-lspconfig`、`nvim-treesitter`、`mason-lspconfig.nvim`、`md-render.nvim`、`sidekick.nvim`。当次升级后实测（不代表本次替换已验证）：启动退出码 0、`checkhealth` 无新增配置类告警、24 个 Treesitter 解析器（lua/java/cpp 逐个加载通过）、`lua_ls` 照常 attach。
> **最后更新**：2026-10-04（Java/Spring：`<leader>sr` 改为「自动识别主类」—— 多入口弹选择框、含「全部启动」、每个主类一个终端槽，新增 `core/java_main.lua`；`<leader>Jd` 重新扫描主类。用户文档侧 `nvim快捷键.md` / `从零搭建依赖清单.md` / `构建SpringBoot项目实操指南.md` 已删除，快捷键速查改看 `<leader>hk`）
