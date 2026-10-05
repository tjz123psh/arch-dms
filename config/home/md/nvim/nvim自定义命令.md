# Neovim 自定义命令速查表

> 核心命令由 `lua/core/commands.lua` 注册或调用模块的 `setup()`；项目列表在 `core/projects.lua`，向导在 `core/spring_wizard.lua`，皮肤在 `core/ui.lua`，Java 专用命令由语言插件注册。

| 命令 | 用途 |
|------|------|
| `:R` | 用 `luafile` 执行当前 `.lua` 文件的磁盘内容 |
| `:A` | 返回启动欢迎页 |
| `:LspInfo` | 查看当前缓冲区 LSP 客户端状态 |
| `:LspLog` | 打开 LSP 日志文件 |
| `:Projects` | 打开项目列表，首次打开同步读取项目历史，回车切换项目并刷新文件树 |
| `:JavaBuildProjects` | 让 jdtls 重新导入并构建项目（改了 `pom.xml` / `build.gradle*` 依赖后用） |
| `:JavaSetRuntime` | 切换 jdtls 使用的 JDK 运行时（IDEA 的 Project SDK）；`Tab` 可补全运行时候选名 |
| `:SpringBootCreate` | 打开 Spring Boot 项目向导（与全局键 `<leader>sp` 等价，任何缓冲区可用；commands 启动时调用 `core.spring_wizard.setup()` 注册） |
| `:JavaRun` | 运行当前 Java 源文件；无 package 走 `java 文件.java`，有 package 走 `javac -sourcepath` 按需编译后运行 |

## Markdown 插件命令（非核心自定义命令）

Markdown 编辑区美化由 `lua/plugins/markdown.lua` 中的 render-markdown.nvim 提供，打开 Markdown 自动加载，无需独立预览窗。

| 命令 | 用途 |
|------|------|
| `:RenderMarkdown buf_toggle` | 当前缓冲区美化开关，同 `<leader>Mp` |
| `:RenderMarkdown buf_enable` / `buf_disable` | 仅启用 / 关闭当前缓冲区美化 |
| `:RenderMarkdown enable` / `disable` / `toggle` | 全局启用 / 关闭 / 切换 |

普通/命令模式渲染，插入/可视模式回源码，光标行 anti_conceal；旧 `:MdRender` 与 `<leader>Mt` / `<leader>Ms` 不再使用。这些命令由插件提供，不在 `core/commands.lua` 重复注册。

## 使用说明

- `:R` — 只执行当前磁盘文件，不自动保存、不清 `require` 缓存，也不保证应用返回的插件 spec。修改插件配置后，保存并重启 Neovim 是可靠方式。
- `:A` — 先加载 alpha-nvim，再回到启动欢迎界面
- `:LspInfo` — 0.12 移除了内置 `:LspInfo`，手动恢复
- `:LspLog` — 0.12 移除了内置 `:LspLog`，手动恢复
- `:Projects` — `commands.lua` 调用 `core.projects.setup()`；模块集中项目历史、`DirChanged` 记录与命令注册。同步读历史，列表取只追加副本（`~/.local/state/nvim/project-history.list`）∪ 插件历史 ∪ 会话项目；打开时 append 回填插件缺项。连同 `plugins/project.lua` 永不截断的写守卫保留四层保护，避免异步读取和并发截断造成历史丢失；并发可能产生重复行，读取去重。使用 `source = "project-history"` 与 `project_dir` 字段，避免撞上 snacks 内置源和保留字段。当前项目置顶，回车切项目并刷新文件树，保持紧凑样式。
- `:JavaBuildProjects` — 让 jdtls 重新导入并按项目构建工具（Maven/Gradle）构建，走 LSP 请求 `java/buildProjects`（命令启动即注册；无 jdtls 时提示先打开 Java 项目）；项目根由 jdtls 按 `pom.xml` / `build.gradle*` / `.git` / `src` 自动识别，不需要手工生成 `pom.xml` 标记（原 `:JavaInit` 已删除）
- `:JavaSetRuntime` — 切换 jdtls 的 JDK 运行时（IDEA 的 Project SDK；命令启动即注册，无 jdtls 时给提示）；候选来自 `java.lua` 里 `settings.java.configuration.runtimes` 配置的本机 JDK（本机 `JavaSE-21` 为默认、`JavaSE-1.8`；路径不存在会自动跳过），`Tab` 补全候选名
- `:SpringBootCreate` — 打开 Spring Boot 项目向导（`snacks.picker` 版）；由 `core/commands.lua` 在启动时调用 `core.spring_wizard` 注册，所以刚启动就能用（`<leader>sp` 是全局键，任何缓冲区都走同一向导）
- `:JavaRun` — 无 `package` 时直接在 Neovim 原生终端跑 `java 当前文件.java`；有 `package` 时推导包根，执行 `javac -d 临时目录 -sourcepath . 当前相对路径.java`，再用 `java -cp 临时目录 包名.类名` 运行，避免编译无关练习文件

## 自动保存的退出约定（2026-10-05）

- 普通 `:q` / `:qa` 保留自动保存；`ZZ` / `:wq!` / `:x!` 仍按保存退出处理。
- 直接输入的 `:q!` / `:qa!` / `:quitall!` / `:cq`，包括合法缩写、计数与 `:silent` 修饰符，都不会被退出自动保存覆盖。`ZQ` 关闭当前窗口，不是退出所有窗口。
- 分屏中丢弃关闭一窗后，剩余窗口的离开缓冲区/失去焦点自动保存立即恢复；取消命令或执行失败的命令也不会永久关闭自动保存。
- 保护范围是当前尚未写盘的修改，不会撤销先前已经发生的自动保存。插件/Lua 的间接退出不靠解析字符串猜测，需要丢弃时调用 `require("core.autocmds").quit_without_save()`；不要用 `normal! ZQ` 绕过保护映射。
