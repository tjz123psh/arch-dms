# 语言配置：一个语言，一个目录

先打开对应语言的入口，再修改需要的实现。不要到插件层重复添加语言清单。

## 目录与职责

- [注册入口](<init.lua>)：显式列出语言，合并声明并检查冲突；不会扫描 helper 当作插件。
- 每种语言的 `init.lua`：该语言配置的唯一入口。简单语言只需要这一个文件，复杂功能继续放在同目录。
- [Java](<java/init.lua>)：偏好、工具、格式化、命令、按键；[语言服务](<java/lsp.lua>)、[缓冲区键位](<java/keymaps.lua>)、[源码运行/模板](<java/files.lua>)、[项目构建](<java/project.lua>)、[调试](<java/debug.lua>)各自维护。[Spring](<java/spring/init.lua>)包含[运行](<java/spring/run.lua>)和[项目向导](<java/spring/wizard.lua>)，不散落到核心目录。
- 共享目录只放真正共享的能力：[通用 LSP 按键](<shared/lsp.lua>)、[标准代码动作](<shared/actions.lua>)、[clangd](<shared/clangd.lua>)、[codelldb](<shared/codelldb.lua>)和[辅助解析器/工具](<shared/init.lua>)。
- [插件接入桥](<../plugins/languages.lua>)读取声明中的插件；LSP、DAP、Conform、Mason、Treesitter 的公共插件只消费汇总结果。

当前保留 12 种：c、cpp、go、java、rust、lua、html、css、json、yaml、xml、markdown。Python、Bash、Vim、JavaScript、TypeScript、Vue、Svelte 的独立入口和专属高亮/缩进声明已按用户要求移除；不迁入共享层。已安装解析器与工具没有卸载，Neovim 自身编辑能力和全局默认选项不受影响。

## 入口声明

所有字段可选；只写当前语言实际使用的部分。

| 字段 | 内容 |
|---|---|
| lsp | 服务名 → Neovim LSP 配置；需要晚读 runtimepath 时可用零参工厂函数 |
| lsp_enabled | 服务名 → 启用条件函数；只控制 LSP，不丢弃该语言其它能力 |
| managed_lsp | 由专门插件管理的服务名；不允许同时出现在 lsp 中 |
| tools | Mason 包名，仅作为手动安装清单 |
| treesitter | parsers / filetypes / indent 三个列表 |
| formatters / formatter_options | 文件类型的格式器列表 / 格式器选项 |
| format_on_save | 文件类型 → 布尔值；未设置时采用公共默认策略 |
| filetypes | vim.filetype.add 的 extension / filename / pattern |
| buffer_options | 文件类型 → 局部编辑选项 |
| plugins | lazy.nvim spec 列表；重实现必须放回调里 |
| commands | 命令名 → callback、opts |
| keys | 全局语言键，格式与 lazy keys 相同；缓冲区键在语言实现里按需注册 |
| actions | 文件类型 → 增强动作；没有增强时共享层请求标准 LSP 动作 |
| dap | adapters / configurations；适配器可以是 DAP 标准回调函数 |

这里的 DAP 适配器函数接收 callback/config，不是零参配置工厂。不要在注册入口主动调用它；codelldb 和 delve 只在真正调试时解析可执行路径。

## 扩展步骤

1. 在语言目录内修改或添加实现；新增语言则创建它的入口，并加入[注册表](<init.lua>)的 names。
2. 一个配置只声明一次。C/C++ 共用 clangd，C/C++/Rust 共用 codelldb，但彼此不 require 另一种语言。
3. require 入口时只创建声明：不启动服务、调试器、终端、网络请求，也不读取过早的 runtimepath。
4. 运行[结构测试](<../../tests/languages.lua>)与相关语言回归。重复普通/自管 LSP、冲突共享配置、漏声明调试适配器、重复命令/按键会明确报错。
5. 新键同步[速查](</home/pang/.config/nvim/lua/core/ui/reference.lua>)及[菜单](<../plugins/whichkey.lua>)，更新[用户架构文档](</home/pang/md/nvim/nvim配置架构.md>)。不要用兼容转接文件长期保留旧路径。

配置改动后重启 Neovim；重新执行某个 Lua 文件不等于完整重载整个语言层。
