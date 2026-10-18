-- 通用 LSP 键位；手动管理的语言服务也显式调用这里。
-- 不按初始化时的静态 capability 门控，避免漏掉动态注册能力。
return function(_client, bufnr)
  local function map(mode, lhs, rhs, d)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = d })
  end

  -- 代码导航
  map("n", "gd", vim.lsp.buf.definition, "跳转到定义")
  map("n", "gR", vim.lsp.buf.type_definition, "跳转到类型定义")
  map("n", "gh", vim.lsp.buf.hover, "悬停显示文档")
  -- 不映射 gr：0.12 已内置 gr 前缀（grn 重命名 / gra 代码操作 / grr 引用 /
  -- gri 实现 / grt 类型定义），覆盖它会同时吃掉这 6 个键
  map("n", "gi", vim.lsp.buf.implementation, "跳转到实现")

  -- 诊断导航
  -- ⚠ 不用 jump({ float = true })：0.12 起该选项已软弃用（runtime/lua/vim/diagnostic.lua:1236
  --   vim.deprecate('opts.float', 'opts.on_jump', '0.14')），0.13 会每次告警、0.14 移除后
  --   浮动诊断静默消失。显式 on_jump + open_float（正是被弃用选项内部做的事）。
  local function jump_with_float(count)
    vim.diagnostic.jump({
      count = count,
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
      end,
    })
  end
  map("n", "[d", function()
    jump_with_float(-1)
  end, "上一个诊断")
  map("n", "]d", function()
    jump_with_float(1)
  end, "下一个诊断")

  -- 重命名 / 代码操作 / 签名帮助
  map("n", "<leader>rn", vim.lsp.buf.rename, "重命名符号")
  map("n", "<leader>ca", vim.lsp.buf.code_action, "代码操作")
  local actions = require("languages.shared.actions")
  map("n", "<leader>ot", actions.organize_imports, "整理导入（按语言）")
  map({ "n", "x" }, "<leader>Ra", actions.refactor, "可用重构（按语言，支持选区）")
  map("i", "<C-k>", vim.lsp.buf.signature_help, "显示函数签名")
end
