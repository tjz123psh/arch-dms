# Neovim 命令速查表

> 在命令行输入命令按回车执行

## 常用内置命令

| 命令 | 用途 |
|------|------|
| `:e <文件>` | 打开文件 |
| `:w` | 保存 |
| `:q` | 关闭当前窗口 |
| `:wq` | 保存并关闭 |
| `:q!` | 强制关闭（不保存） |
| `:qa` | 关闭所有窗口 |
| `:wa` | 保存所有文件 |
| `:x` | 保存并退出（同 `:wq`） |

## 配置文件相关

| 命令 | 用途 |
|------|------|
| `:so $MYVIMRC` | 重新加载 `init.lua`（部分生效） |
| `:luafile %` | 将当前 `.lua` 文件作为 Lua 执行 |
| `:R` | 执行当前 `.lua` 文件的磁盘内容（等同 `:luafile`，不是完整重载） |
| `:A` | 打开启动欢迎页 |
| `:CheatSheet` | 快捷键速查浮窗（同 `<leader>hk`；2026-09-28 补注册，此前只在注释里声称存在、实报 E492） |
| `:BufDelete [N]` | 关闭缓冲区但**保住分屏布局**（同 `<leader>bd`；内部走 `Snacks.bufdelete`。原生 `:bdelete` 会连窗口一起关掉。带 N 时关第 N 个 buffer，bufferline 的 × 用它） |

> `:R` 不保存缓冲区、不清除 `require` 缓存，也不保证应用插件 spec；修改插件配置后，保存并重启 Neovim 是可靠方式。

## 插件管理

| 命令 | 用途 |
|------|------|
| `:Lazy` | 打开 lazy.nvim 插件管理界面 |
| `:Lazy sync` | 同步/安装/更新所有插件 |
| `:Lazy update` | 更新所有插件 |
| `:Lazy clean` | 清理未使用的插件 |
| `:Lazy check` | 检查插件更新 |
| `:Lazy reload <插件名>` | 重新加载指定插件 |
| `:Lazy restore` | 从 lockfile 恢复插件版本 |
| `:ToggleTerm` | 打开/关闭终端（toggleterm；等价 `<leader>tt`） |
| `:TSInstall` / `:TSUpdate` / `:TSConfigInfo` | nvim-treesitter 解析器：安装 / 更新 / 查看配置信息（插件自带命令） |

## 工具安装与诊断

| 命令 | 用途 |
|------|------|
| `:Mason` | 打开 Mason 界面（安装 LSP、格式化器、调试器） |
| `:MasonInstall <包名>` | 安装指定工具（如 `:MasonInstall clangd pyright`） |
| `:MasonUninstall <包名>` | 卸载指定工具 |
| `:MasonUpdate` | 更新 Mason 注册表 |

## 健康检查

| 命令 | 用途 |
|------|------|
| `:checkhealth` | 运行全部健康检查 |
| `:checkhealth vim.deprecated` | 查看弃用 API 警告 |
| `:checkhealth vim.lsp` | 检查内置 LSP 配置、命令和 filetype |
| `:checkhealth lazy` | 检查 lazy.nvim 状态 |
| `:checkhealth mason` | 检查 Mason 状态 |
| `:checkhealth snacks` | 检查 snacks.nvim（picker/input）状态 |

## 信息查看

| 命令 | 用途 |
|------|------|
| `:messages` | 查看最近的消息/日志 |
| `:LspInfo` | 查看当前缓冲区 LSP 客户端状态 |
| `:LspLog` | 打开 LSP 日志文件 |
| `:lua require("snacks").picker.keymaps()` | 查看所有快捷键映射（snacks picker） |
| `:lua require("snacks").picker.help()` | 搜索帮助文档 |
| `:lua require("snacks").picker.diagnostics()` | 查看所有诊断（错误/警告） |
| `:lua require("snacks").picker.commands()` | 搜索所有可用命令 |

## 中文标点转半角

| 命令 | 用途 |
|------|------|
| `:CJKPunct` | 开关「插入模式下全角标点自动转半角」（默认开；`，`→`,`、`。`→`.`、`；`→`;`、`：`→`:`、`！`→`!`、`？`→`?`、括号/引号同理） |
| `:CJKPunctFix` | 把**当前缓冲区**（或可视选区 `:'<,'>CJKPunctFix`）里已有的全角标点转成半角 —— 粘贴进来的内容不会触发自动转换，用这个补。范围三种写法都支持：无范围 = 全文、`:2CJKPunctFix` = 只改第 2 行、`:2,5CJKPunctFix` = 2~5 行（2026-09-25 修：单地址曾会越界改全文） |

> 默认在 `markdown` / `text` / `gitcommit` / `help` 里**不转**（这些场景中文标点才是对的）；想让它在所有文件类型生效，把 `lua/core/cjk_punct.lua` 里的 `exclude_ft` 清空即可。

## Mason 工具（手动）

| 命令 | 用途 |
|------|------|
| `:MasonToolsInstall` | 按 [手动工具清单](</home/pang/.config/nvim/lua/plugins/mason-tool-installer.lua>) 补齐缺失的全部已配置 LSP、调试器和格式化工具 |
| `:MasonToolsUpdate` | 手动检查并更新清单内的工具 |
| `:LspInstall <服务器名>` | 按需加载 LSP 安装器并安装指定服务器，如 `:LspInstall lua_ls`；不顺带安装整个清单 |
| `:LspUninstall <服务器名>` | 手动卸载指定服务器，支持 LSP 名称映射 |
| `:Mason` | 打开 Mason 界面手动装/删 |

> 2026-10-05 补齐启动保护：mason-lspconfig 不再作为启动依赖，只由手动 `:LspInstall` / `:LspUninstall` 加载；批量清单统一使用 Mason 包名并关闭别名集成，避免又被 require 提前加载。`run_on_start = false` 保留。Mason 启动不刷新/补装，显式安装/更新命令仍可联网。

## Markdown 编辑区美化（render-markdown.nvim）

打开 Markdown 时按 FileType 自动加载，直接在原编辑窗口内渲染，不需要浏览器或独立预览浮窗。普通/命令模式渲染，插入/可视模式显示源码；光标行通过 anti_conceal 显示源码，方便修改。

| 命令 | 用途 |
|------|------|
| `:RenderMarkdown buf_toggle` | 切换**当前缓冲区**美化（同 `<leader>Mp`） |
| `:RenderMarkdown buf_enable` | 启用**当前缓冲区**美化 |
| `:RenderMarkdown buf_disable` | 关闭**当前缓冲区**美化 |
| `:RenderMarkdown enable` / `disable` / `toggle` | 全局启用 / 关闭 / 切换，不是仅当前缓冲区 |

旧 `:MdRender` 命令与 `<leader>Mt` / `<leader>Ms` 已退出当前方案。标题和代码块不画整块底色以适配透明主题；LaTeX 暂不启用，不为此额外安装工具，也不承诺浏览器级图片、Mermaid 或 LaTeX 效果。

## AI CLI（sidekick）

| 命令 | 用途 |
|------|------|
| `:Sidekick cli show name=codex` | 直接打开指定 AI CLI 面板（`name=` 换成 grok / opencode 等） |
| `:Sidekick cli select` | 弹选择器挑工具（只列已安装） |
| `:Sidekick cli close` | 关闭所选已连接会话的终端；当前不用 mux，会停止对应终端 job（同 `<leader>ad`，不同于开关面板） |
| `:checkhealth sidekick` | 健康检查（插件是懒加载的，要先 `:Lazy load sidekick.nvim` 或按一次 `<leader>aa` 才认得） |
| `:Lazy load sidekick.nvim` | 手动加载插件（排查用） |

> 当前不用 tmux/zellij。`<leader>aa` 只切换显示/隐藏，隐藏不会调用停止进程；改 CLI 主题后是否需重启取决于 CLI，不能靠隐藏再显示保证生效。

## 打开指定 UI

| 命令 | 用途 |
|------|------|
| `:Alpha` | 打开启动欢迎页 |
| `:Neotree` | 打开文件树 |
| `:Neotree toggle` | 切换文件树开关 |
| `:lua require("snacks").picker.files()` | 搜索文件名（同 `<leader>ff`） |
| `:lua require("snacks").picker.grep()` | 搜索文件内容（同 `<leader>fg`） |
| `:lua require("snacks").picker.buffers()` | 切换已打开的缓冲区（同 `<leader>fb`） |
| `:lua require("snacks").picker.recent()` | 查看最近打开的文件（启动页 `r` 同款） |
| `:PickerSkin soft` / `:PickerSkin pink` | 切换 picker 皮肤（默认 soft；即时生效） |
| `:Projects` | 打开项目列表（当前项目置顶并标 `当前`；列表来自"自维护副本 ∪ 插件历史 ∪ 会话项目"，不会被插件的截断写弄丢），回车切换项目并打开/刷新文件树 |

## 调试命令

| 命令 | 用途 |
|------|------|
| `:DapNew` | 创建 / 编辑调试配置（交互式界面） |
| `:DapContinue` | 开始 / 继续调试 |
| `:DapToggleBreakpoint` | 切换断点 |

## Java

| 命令 | 用途 |
|------|------|
| `:JavaRun` | 运行当前 Java 源文件；有 package 时按需编译当前文件和依赖源码后运行 |
| `:JavaBuildProjects` | 让 jdtls 重新导入并构建项目（走 LSP 的 `java/buildProjects`，不需要外部 `mvn`）；有多个项目时会让你先选。⚠ 命令在**启动时即注册**（lazy `cmd` 桩），但没有 Java 缓冲区/jdtls 时会提示"需要先打开一个 Java 项目" |
| `:JavaSetRuntime` | 切换 jdtls 使用的 JDK 运行时（相当于 IDEA 的 Project SDK）；不带参数弹选择列表，`Tab` 补全当前可选项（本机 `JavaSE-21`、`JavaSE-1.8`）。同上：启动即可用，无 jdtls 时给提示而不是报错 |
| `:SpringBootCreate` | 打开 Spring Boot 项目向导（`snacks.picker` 版，与 `<leader>sp` 等价；命令在启动时即注册，不依赖插件懒加载） |
| `:SpringBoot` | Spring 符号查询（spring-boot.nvim）：不带参数弹选择列表（Annotations / Beans / RequestMappings / Prototype），也可直接 `:SpringBoot @`。要求当前缓冲区已挂上 `spring-boot` 语言服务器（打开 Java/YAML 项目后自动起）；命令同样启动即存在（lazy `cmd` 桩） |

> 项目根由 jdtls 自动识别（`pom.xml` / `build.gradle*` / `.git` / `src`），不需要手工生成标记文件；原 `:JavaInit` 已删除（该命令不存在）。

> 运行 Spring Boot 项目用 `<leader>sr`（**键位**，不是命令）：先扫 `src/main/java` 下的主类 —— 只有一个直接启动，多个弹选择框（列出终端槽、`← pom 默认`、`● 已在跑`，并附一项「▶ 全部启动」）；Maven 走 `spring-boot:run`、Gradle 走 `bootRun`。终端按“项目路径＋主类”独占分配，构建/测试另用该项目的专用终端；保留通用终端 1/2/3。同一个类再按一次会先发 Ctrl-C、等旧进程退出再重启（超过 10 秒不强行发送命令）。启动通知/选择框显示编号，重开用 `:<编号>ToggleTerm`，例如 `:4ToggleTerm`；`<leader>th` 仍只打开通用 2 号终端。

Java 测试与调试：`<leader>Jt` 按 Treesitter 定位光标所在方法，多行参数和同行注解均支持；不在方法内、语法不完整或解析器缺失时提示并停止，不猜前一个方法。`<leader>JT` 运行当前类（含可识别的成员内部类；匿名类/局部类不猜名称）。构建/测试未结束时拒绝叠加命令。`<F5>` 每次从当前项目查询主类，不复用其它项目的旧列表；已有调试会话时仍是继续。`<leader>Jd` 只重新查询当前项目并报告数量，不启动调试。

## 快捷键速查

| 命令 | 用途 |
|------|------|
| `:lua require("snacks").picker.keymaps()` | 在所有快捷键里搜索 |
| `<leader>hk` | 打开/关闭个人快捷键速查浮动窗口 |
| `ZQ` | 放弃当前窗口尚未写盘的修改并关闭；与输入 `:q!` 一样受自动保存保护 |
| `<leader>ca` | 所有可用 LSP 代码操作 |
| `<leader>Ra` | 当前可用的重构列表；支持光标和字符/整行选区，不自动执行 |
| `<leader>ot` | 按语言整理导入；Java 保留 jdtls 增强，其余仅执行标准整理动作；不支持时不格式化兜底 |
| `<leader>sp` | Spring Boot 项目向导（**全局键**，任何缓冲区可用，不限 Java）。原 `<leader>sP` 原版向导已于 2026-09-25 删除 |
| `<leader>sr` | 运行 Spring Boot 项目（自动识别主类；多个入口弹选择框，含「全部启动」，每个主类一个终端） |
| `:map` | 列出普通模式快捷键 |
| `:imap` | 列出插入模式快捷键 |
| `:vmap` | 列出可视模式快捷键 |
| `:tmap` | 列出终端模式快捷键 |

> 完整快捷键按 `<leader>hk` 看速查面板（`core/cheatsheet.lua`），或在面板外用 `:lua require("snacks").picker.keymaps()` 搜索；此前的独立快捷键文档 `nvim快捷键.md` 已删除。
