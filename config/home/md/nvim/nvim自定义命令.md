# Neovim 自定义命令速查表

> 通用入口在[核心命令](</home/pang/.config/nvim/lua/core/commands.lua>)，LspInfo/LspLog 在[诊断模块](</home/pang/.config/nvim/lua/core/diagnostics.lua>)，项目入口在[项目模块](</home/pang/.config/nvim/lua/core/projects/init.lua>)；语言命令由各语言声明和[注册表](</home/pang/.config/nvim/lua/languages/init.lua>)管理。

| 命令 | 用途 |
|------|------|
| `:R` | 用 `luafile` 执行当前 `.lua` 文件的磁盘内容 |
| `:A` | 返回启动欢迎页 |
| `:CheatSheet` | 按需打开快捷键速查，同 `<leader>hk` |
| `:LspInfo` | 查看所有活跃 LSP 客户端、根目录和文件类型 |
| `:LspLog` | 打开 LSP 日志文件 |
| `:Projects` | 打开项目列表，首次打开同步读取项目历史，回车切换项目并刷新文件树 |
| `:JavaBuildProjects` | 让 jdtls 重新导入并构建项目（改了 `pom.xml` / `build.gradle*` 依赖后用） |
| `:JavaSetRuntime` | 切换 jdtls 使用的 JDK 运行时（IDEA 的 Project SDK）；`Tab` 可补全运行时候选名 |
| `:SpringBootCreate` | 全局 11 步向导（同 `<leader>sp`）；调用时才加载向导，使用官方 Initializr，无需 spring CLI |
| `:JavaRun` | 保存后在临时目录编译当前源码及所需辅助源码，分屏终端运行并接收 stdin；同 `<leader>Jr` |

## Markdown 插件命令（非核心自定义命令）

Markdown 编辑区美化由 `lua/languages/markdown/render.lua` 中的 render-markdown.nvim 提供，打开 Markdown 或 `.mdx` 自动加载，无需独立预览窗。

| 命令 | 用途 |
|------|------|
| `:RenderMarkdown buf_toggle` | 当前缓冲区美化开关，同 `<leader>Mp` |
| `:RenderMarkdown expand` / `contract` | 光标行上下多露 / 少露一行源码，同 `<leader>Me` / `<leader>Mc` |
| `:RenderMarkdown buf_enable` / `buf_disable` | 仅启用 / 关闭当前缓冲区美化 |
| `:RenderMarkdown enable` / `disable` / `toggle` | 全局启用 / 关闭 / 切换 |

普通/命令模式渲染，插入/可视模式回源码，光标行 anti_conceal；旧 `:MdRender` 与 `<leader>Mt` / `<leader>Ms` 不再使用。这些命令由插件提供，不在 `core/commands.lua` 重复注册。

## 使用说明

- `:R` — 只执行当前磁盘文件，不自动保存、不清 `require` 缓存，也不保证应用返回的插件 spec。修改插件配置后，保存并重启 Neovim 是可靠方式。
- `:A` — 调用 Alpha 的既有懒加载命令，再打开欢迎页。
- `:LspInfo` — 保留兼容入口，列出全部活跃客户端。
- `:LspLog` — 打开 Neovim 当前 LSP 日志。
- `:Projects` — [历史模块](</home/pang/.config/nvim/lua/core/projects/history.lua>)负责自有副本、插件历史和会话项目的合并、只追加回填与写守卫；[选择器](</home/pang/.config/nvim/lua/core/projects/picker.lua>)只处理排序、显示和确认。最长根置顶、独立 project-history 源、project_dir 字段和空格路径处理不变。
- `:JavaBuildProjects` — 当前 Java 缓冲区必须已附加 jdtls；构建根优先从 Maven/Gradle/Eclipse 标记确定，独立文件按文件目录或包根，不依赖启动 Neovim 时的 cwd。
- `:JavaSetRuntime` — 候选由[Java 模块](</home/pang/.config/nvim/lua/languages/java/lsp.lua>)检查本机已安装 JDK；JavaSE-21 默认、JavaSE-1.8 可选。无参数传 nil 以显示列表。该选择不改变 JavaRun 使用的 PATH 工具。
- `:SpringBootCreate` — 在[Java 入口](</home/pang/.config/nvim/lua/languages/java/init.lua>)声明，由语言注册表统一注册；[向导](</home/pang/.config/nvim/lua/languages/java/spring/wizard.lua>)按需加载。需要 curl/unzip/GNU mv，失败或同名目标不会覆盖项目。
- `:JavaRun` — [源码运行器](</home/pang/.config/nvim/lua/languages/java/files.lua>)明确保存，javac 只编译当前文件及所需源码，java 在源码根接收终端输入；类文件仅位于本次临时目录，退出即清理。保存失败、包目录不匹配会停止；第三方依赖项目用 F5/构建工具。

## 自动保存的退出约定（2026-10-05）

- 普通 `:q` / `:qa` 保留自动保存；`ZZ` / `:wq!` / `:x!` 仍按保存退出处理。
- 直接输入的 `:q!` / `:qa!` / `:quitall!` / `:cq`，包括合法缩写、计数与 `:silent` 修饰符，都不会被退出自动保存覆盖。`ZQ` 关闭当前窗口，不是退出所有窗口。
- 分屏中丢弃关闭一窗后，剩余窗口的离开缓冲区/失去焦点自动保存立即恢复；取消命令或执行失败的命令也不会永久关闭自动保存。
- 保护范围是当前尚未写盘的修改，不会撤销先前已经发生的自动保存。插件/Lua 的间接退出不靠解析字符串猜测，需要丢弃时调用 `require("core.autocmds").quit_without_save()`；不要用 `normal! ZQ` 绕过保护映射。
