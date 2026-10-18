-- 核心配置加载器

require("core.options") -- 编辑器全局设置（行号、缩进、搜索等）
require("core.diagnostics").setup() -- 诊断显示、折行和 LSP 日志轮转
require("core.keymaps") -- 全局快捷键映射
require("core.commands") -- 编辑器通用命令；语言命令由 languages.setup() 注册
require("core.autocmds") -- 自动命令（特定操作的自动触发）
require("core.cjk_punct") -- 中文标点输入即转半角（:CJKPunct 开关 / :CJKPunctFix 整篇转换）
