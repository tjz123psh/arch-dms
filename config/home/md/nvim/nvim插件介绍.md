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
| **备注** | 只启用 CLI，`nes.enabled = false`，不接 Copilot；健康检查前先加载插件，未启用 Copilot LSP 的提示属预期。当前不用 tmux/zellij：`<leader>aa` 调用 toggle，只显示/隐藏终端，不停止 job；`<leader>ad` / `:Sidekick cli close` 走 detach → terminal close，会停止对应终端 job 并清理 buffer。面板保持上游默认的**右侧分屏**（`cli.win.layout = "right"`）。⚠ 面板窗口把 `Normal`/`NormalNC`/`EndOfBuffer`/`SignColumn` 映射到 `SidekickChat`，而上游**从未定义**这个组；WinHighlight 指向未定义的组时 Neovim 会退回「UI 默认背景」（猫猫 base `#1e1e2e`）⇒ 透明主题下编辑区透出桌面、只有面板是一整块实心色（抓包实测：该区域的 SGR 里带 `48;2;30;30;46`）。修复在 [sidekick.lua](</home/pang/.config/nvim/lua/plugins/sidekick.lua>) 的 `config` 里把该组 `link = "Normal"`，面板即与编辑区一致、换主题自动跟随（修复后同一位置不再带背景色）。⚠ 分屏在 Neovim 里没有边框，**四角必然是直角**；`winborder = rounded` 只作用于浮窗，想圆角只能把面板改成浮窗（代价：浮在编辑区之上、不再挤压编辑区、分屏导航键失效）。
CLI 主题是否需要重启由 CLI 决定，隐藏再显示不保证重读主题。终端真彩色由 `core/options.lua` 在用户未设置时补 `COLORTERM=truecolor`。 |

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
| **备注** | [项目接线](</home/pang/.config/nvim/lua/core/projects/init.lua>)维护 LSP 根兼容和文件树刷新，[历史模块](</home/pang/.config/nvim/lua/core/projects/history.lua>)维护三源并集、自有副本、append 回填和永不截断的写守卫；插件声明不再嵌入历史实现。 ；`exclude_dirs = { "~/obsidian/*" }` 让 Obsidian 笔记库不参与自动跳根——整库一个 `.git`，否则在库里打开任何笔记都会把 cwd 切到库根，文件树（`bind_to_cwd`）随之搬走 |

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
| **功能** | 命令行与通知美化；输入窗共享[尺寸策略](</home/pang/.config/nvim/lua/core/ui/input.lua>)，使用 width="auto"，min_width 是加载时的数字快照。cmdline_input 继承 cmdline_popup，不重复写同一份样式；两种输入框不承诺 resize 后完全重合。 |
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
| **功能** | 统一提供搜索/选择器与 `vim.ui.input` 输入框；Noice 仍负责命令行和消息，Alpha 负责欢迎页。输入框与 Noice 共用 [输入尺寸](</home/pang/.config/nvim/lua/core/ui/input.lua>) 的尺寸策略，但 Noice 最小宽度仅在加载时求值，且两种边框位置仍可能差一行，不保证 resize 后完全等宽等高。 |
| **配置** | `plugins/snacks.lua` 配置 picker/input，从默认键位拷贝后追加映射；调用 `core.ui.setup()` 统一皮肤。普通 picker 和 `vim.ui.select` 使用 `picker_compact`；grep 单独构造列表/预览布局，不对 select 的布局数组做深合并，避免残留旧节点。 |
| **布局** | grep（`<leader>fg`）在宽屏（≥120 列）使用左侧输入/列表、右侧预览，窄屏改为上方输入/列表、下方预览。其他 picker 继续紧凑且默认无预览，原有键位不变。项目列表（`:Projects`）单独放大尺寸：紧凑预设只有 55% 宽 / 40% 高，项目少时显得太小，现按 `宽 = clamp(columns*0.8, ≥内容宽, 160)`、`高 = clamp(lines*0.6, 8, lines-4)` 取整屏比例（140×55 实测列表 110×29、整框 33 行；80×24 → 64×10 / 14 行；60×18 → 48×6 / 10 行，不会超出屏幕）。其它 picker 与 `vim.ui.select` 仍用 `picker_compact` 原尺寸。 |
| **加载** | `lazy = false`，`priority = 1000`；`vim.ui.select`/`vim.ui.input` 在 **UIEnter** 时正式接管（headless 测不到，真 TTY 实测来源为 `snacks/picker/init.lua`、`snacks/input.lua`） |
| **快捷键** | picker 内：`<CR>` 确认、`<Tab>`/`<S-Tab>` 多选切换、`<Esc>` 一次关闭、方向键上下；另追加 `<C-j>`/`<C-k>` 与 `<C-n>`/`<C-p>` 上下移动 |
| **皮肤** | [共享 UI](</home/pang/.config/nvim/lua/core/ui/init.lua>) 集中 soft/pink 色板、高亮、`:PickerSkin` 和 `ColorScheme` 重设；默认 soft，`:PickerSkin soft` / `:PickerSkin pink` 即时切换。Spring 向导读取同一色板，不另写共享高亮。标题、边框和选中行需覆盖 snacks 实际使用的组（如 `SnacksTitle`、`SnacksPickerBoxBorder`、`SnacksPickerListCursorLine`），避免主题默认色漏出。 |
| **行渲染** | picker 的 `format = function(item, picker)` 支持 chunk 数组 `{ {文本, 高亮组}, ... }`，可做图标列/多色排版（`:Projects` 就是"蓝色文件夹图标 + 项目名亮色 + 父目录灰色"）；snacks 会在**渲染后的文本**上重算匹配高亮，`resolve = function(max_width)` 的 chunk 能做宽度感知截断 |
| **备注** | 只启用 picker/input，保留 notifier/dashboard/terminal/explorer 四项职责护栏，其余未配置模块不自动启用。窗口键表从 defaults 拷贝，仅覆盖 Esc 一次取消，避免丢失确认/多选默认键；项目、Java 多选和 Spring 向导各用独立 source。 |

### MeanderingProgrammer/render-markdown.nvim

| 项目 | 说明 |
|------|------|
| **功能** | 直接美化原 Markdown 编辑区的标题、列表、引用、表格、链接和代码块，不打开浏览器或独立预览窗口，不改写文件内容 |
| **配置** | `lua/languages/markdown/render.lua`；`ft = { "markdown", "markdown.mdx" }`（lazy 的 `ft` 同时决定插件生效的 `file_types`，所以 `.mdx` 也渲染），Markdown FileType 自动加载 |
| **模式** | 普通/命令模式渲染，插入/可视模式回到源码；光标行启用 anti_conceal，方便看清并修改标记 |
| **透明主题** | 标题 `heading.backgrounds = {}`；代码块 `disable_background = true`、`style = "language"`、`border = "none"`，禁用 sign；避免整行底色和额外边框。catppuccin 启用 `render_markdown` 集成 |
| **依赖** | 复用现有 nvim-treesitter 与 nvim-web-devicons；LaTeX 暂不启用，不额外安装转换工具；不承诺浏览器级图片、Mermaid 或 LaTeX 渲染 |
| **快捷键** | `<leader>Mp` 仅切换当前缓冲区美化；`<leader>Me` / `<leader>Mc` 让光标行上下多露 / 少露一行源码（插件 `expand()` / `contract()`，读长段落时对照原文用）；旧 `<leader>Mt` / `<leader>Ms` 移除 |
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
| **备注** | 解析器清单由保留语言及共享声明汇总，当前为 c/cpp、css/scss、go、html、java、json、lua、markdown/markdown_inline、rust、yaml，以及 diff/query/regex，共16项。2026-10-15 不再声明 Bash、Vim/Vimdoc、JavaScript、TypeScript/TSX、Vue、Svelte；已安装解析器不卸载。安装前仍兼容 Mason CLI，缺失解析器的自动下载保留6小时节流。 |

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
|---|---|
| **功能** | Java 补全、导航、重构、调试；单文件和 Maven/Gradle 项目都可用 |
| **配置** | [Java 入口](</home/pang/.config/nvim/lua/languages/java/init.lua>)统一声明插件、偏好、工具、格式化、命令与全局键；实现继续放 Java 目录 |
| **加载** | Java FileType；JavaBuildProjects / JavaSetRuntime 有 lazy 命令入口 |
| **依赖** | Mason 的 jdtls、java-debug-adapter、java-test；Java Treesitter 解析器；调试使用 nvim-dap |
| **运行/测试** | Jr/JavaRun 单源码终端运行；F5 当前项目调试；Jt/JT 构建工具测试；Jg/JG jdtls 最近测试方法/文件测试类调试 |
| **保留保护** | 独立工作区、同根复用/重载重附加、客户端命令转发、Lombok agent、Java 语义高亮关闭、跨项目 DAP 回调失效与终端归属保护 |

包名、主类、测试位置共用[语法解析](</home/pang/.config/nvim/lua/languages/java/syntax.lua>)，不再把注释中的 main 或嵌套类误当作文件主类。[终端管理](</home/pang/.config/nvim/lua/languages/java/terminal.lua>)按项目/用途/主类分配，构建不抢应用 stdin；[调试](</home/pang/.config/nvim/lua/languages/java/debug.lua>)保留固定客户端和超时。DAP 在 Java attach 时仍可能被上游加载，不再宣称“必定等 F5 才加载”。

### JavaHello/spring-boot.nvim

| 项目 | 说明 |
|---|---|
| **功能** | Spring 属性补全、诊断、导航、Bean 与端点查询 |
| **配置** | [springboot.lua](</home/pang/.config/nvim/lua/languages/java/spring/init.lua>)仅负责 Spring 语言服务 |
| **边界** | 仅含 Spring 依赖的构建项目启动；保留 application 文件名过滤，普通算法和普通 YAML 不启动 Spring 服务 |
| **依赖** | Mason 的 vscode-spring-boot-tools；扩展 jars 由 jdtls 加载 |

全局 sp/Java 四种生成键和 JavaRun/SpringBootCreate 由[Java 入口](</home/pang/.config/nvim/lua/languages/java/init.lua>)声明、语言注册表统一接入；[向导](</home/pang/.config/nvim/lua/languages/java/spring/wizard.lua>)与[Spring 运行](</home/pang/.config/nvim/lua/languages/java/spring/run.lua>)都在 Java 的 Spring 子目录。

不再启用 elmcgill/springboot-nvim。它的全局自动填 package 会破坏空算法文件；四种 Class/Interface/Enum/Record 生成改为[一份模板实现](</home/pang/.config/nvim/lua/languages/java/files.lua>)，保存增量编译由 Java 模块在已附加的项目缓冲区执行。旧插件下载目录未卸载，方便回退；原版 SpringBootNewProject 不再是当前入口。

## 独立语言目录

当前12种语言的入口都位于[语言目录](</home/pang/.config/nvim/lua/languages/>)，由[注册表](</home/pang/.config/nvim/lua/languages/init.lua>)统一供公共插件读取；不再在 LSP/格式化/安装器里各维护一份清单。

| 语言 | 入口与已有能力 |
|---|---|
| C / C++ | [C](</home/pang/.config/nvim/lua/languages/c/init.lua>)、[C++](</home/pang/.config/nvim/lua/languages/cpp/init.lua>)各自声明格式化/调试/缩进，共用[clangd](</home/pang/.config/nvim/lua/languages/shared/clangd.lua>)；C 两项、C++ 三项调试配置保留，编译请带调试符号 |
| Rust | [Rust](</home/pang/.config/nvim/lua/languages/rust/init.lua>)集中 rust-analyzer、clippy、rustfmt、DAP 和工具链守卫；不再依赖 C++ 配置先加载 |
| Go | [Go](</home/pang/.config/nvim/lua/languages/go/init.lua>)集中 gopls、gofumpt、分析项、Delve、gotmpl；继续使用 LSP 格式化 |
| Lua | [Lua](</home/pang/.config/nvim/lua/languages/lua/init.lua>)集中 lua_ls、stylua、缩进、:R 和按需 lazydev；runtimepath 在消费 LSP 配置时读取 |
| HTML/CSS/JSON/YAML/XML | 各有独立目录，保留原有服务；XML 排除 xsl，YAML 保留 Compose/GitLab/Helm 别名 |
| Markdown | [Markdown](</home/pang/.config/nvim/lua/languages/markdown/init.lua>)集中 marksman、解析器、mdx、渲染插件和 Mp 键 |

[共享 codelldb](</home/pang/.config/nvim/lua/languages/shared/codelldb.lua>)由 C/C++/Rust 显式引用，路径延迟到真正调试时解析；Go Delve 同理。没有新增插件或安装系统工具。更改语言功能只修改其目录，字段说明见[扩展规范](</home/pang/.config/nvim/lua/languages/README.md>)。

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
| `languages/init.lua` | 自定义 filetype 识别 |
| `languages/shared/lsp.lua` | LSP `on_attach` 的通用键位与诊断（lspconfig 与 jdtls 共用） |
| [Java 模块](</home/pang/.config/nvim/lua/languages/java/>) | 语言服务、项目操作、单文件、语法解析、调试、Spring 运行、终端、多选各自维护 |
| `languages/java/spring/wizard.lua` | Spring Boot 项目向导（11 步；`:SpringBootCreate` / `<leader>sp` 的实现） |
| `plugins/indentline.lua` | indent-blankline.nvim |
| `plugins/mason.lua` | mason.nvim |
| `plugins/mason-tool-installer.lua` | mason-tool-installer.nvim（作为 mason 的依赖随启动期加载 —— 2026-09-25 审查确认旧写的 `event = "VeryLazy"` 是死触发器，已删；`run_on_start = false`，自动补装 codelldb / java-debug-adapter / java-test / lemminx / vscode-spring-boot-tools / delve / stylua / google-java-format / clang-format / tree-sitter-cli） |
| `plugins/neotab.lua` | neotab.nvim |
| `plugins/noice.lua` | noice.nvim |
| `plugins/project.lua` | project.nvim |
| `languages/markdown/render.lua` | render-markdown.nvim（原编辑窗口内美化；`<leader>Mp` 切换当前缓冲区，`<leader>Me` / `<leader>Mc` 多露 / 撤回一行源码；`.mdx` 同样渲染） |
| `plugins/snacks.lua` | snacks.nvim（picker + input，全机唯一 UI 提供者） |
| `plugins/statusline.lua` | lualine.nvim |
| `plugins/terminal.lua` | toggleterm.nvim |
| `plugins/theme.lua` | catppuccin/nvim |
| `plugins/treesitter.lua` | nvim-treesitter |
| `plugins/whichkey.lua` | which-key.nvim |
| `plugins/dap/init.lua` | nvim-dap + nvim-dap-ui + nvim-nio |
| `plugins/lsp/init.lua` | nvim-lspconfig，管理已安装语言服务的启动 |
| [mason-lspconfig.lua](</home/pang/.config/nvim/lua/plugins/mason-lspconfig.lua>) | 按命令加载的手动 LSP 安装入口 |
| `plugins/languages.lua` | 语言配置聚合入口 |
| `languages/cpp/init.lua` | clangd 扩展 + codelldb DAP |
| [java.lua](</home/pang/.config/nvim/lua/languages/java/init.lua>) | nvim-jdtls 声明，逻辑委托 Java 模块 |
| `languages/go/init.lua` | gopls + delve DAP |
| `languages/rust/init.lua` | rust_analyzer 扩展 + codelldb Rust DAP |
| [springboot.lua](</home/pang/.config/nvim/lua/languages/java/spring/init.lua>) | 仅真实 Spring 项目的语言服务 |

---

> **历史记录（本次 Markdown 替换前）**：插件总数 38 个（`~/.local/share/nvim/lazy/` 实际安装目录数，含 lazy.nvim 本身），`lazy-lock.json` 条目数已与之一致。2026-10-04 跑了一次 `:Lazy update`：把 2026-09-28 加入却一直没被写进锁文件的 **lazydev.nvim**（`ft = "lua"`，见 lspconfig 小节的依赖）补上（旧锁文件停在 2026-09-25，只有 37 条），同批 5 个插件升到最新 —— `nvim-lspconfig`、`nvim-treesitter`、`mason-lspconfig.nvim`、`md-render.nvim`、`sidekick.nvim`。当次升级后实测（不代表本次替换已验证）：启动退出码 0、`checkhealth` 无新增配置类告警、24 个 Treesitter 解析器（lua/java/cpp 逐个加载通过）、`lua_ls` 照常 attach。
> **Java/Spring 更新：2026-10-14**。收拢重复逻辑、保留工作流，补齐单文件运行，向导改官方 API；快捷键看 `<leader>hk`，验证方式见[配置架构](</home/pang/md/nvim/nvim配置架构.md>)。

## 配置维护边界

DAP、toggleterm 与 Sidekick 的键位直接在各自 keys 中定义，不再分别写懒加载壳和第二套绑定。Mason 初始化与工具安装器是单向依赖，启动不刷新/安装。当前锁定版 virtual-text 的请求监听参数由[调试配置](</home/pang/.config/nvim/lua/plugins/dap/init.lua>)适配，保留全栈显示并避免错误响应导致异步异常；升级后运行[协议测试](</home/pang/.config/nvim/tests/dap_listener.lua>)核对是否仍需要。
