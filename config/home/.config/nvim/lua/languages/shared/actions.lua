-- 跨语言操作入口：优先保留语言增强，其余只请求标准 LSP 动作，不用标题猜测。
-- 选择范围、kind 二次过滤、codeAction/resolve、WorkspaceEdit 与命令交给 Neovim 原生处理。
local M = {}

local function code_action_clients(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })
end

local function available(bufnr)
  if #code_action_clients(bufnr) > 0 then
    return true
  end
  vim.notify("当前缓冲区没有可用的 LSP 代码操作，请等待语言服务启动", vim.log.levels.WARN)
  return false
end

local function request(kind, apply)
  if not available(0) then
    return
  end
  -- context.only 既告诉服务端筛选范围，也由 Neovim 按 kind 层级再过滤一次。
  -- 没有对应动作时原生入口会提示 No code actions available，不执行其它类别的操作。
  vim.lsp.buf.code_action({
    context = {
      only = { kind },
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    },
    apply = apply,
  })
end

function M.organize_imports()
  local override = require("languages").action(vim.bo.filetype, "organize_imports")
  if override then
    return override()
  end
  -- 只有一个标准整理动作时直接执行；多个来源/动作时交给用户选择。
  -- 不回退到格式化、quickfix 或按标题挑选所谓“整理”，也不会猜删 include/use。
  request("source.organizeImports", true)
end

function M.refactor()
  if vim.api.nvim_get_mode().mode == "\22" then
    vim.notify("重构不支持矩形选区，请改用字符或整行选择", vim.log.levels.INFO)
    return
  end
  -- 普通模式使用光标位置；字符/行可视模式由原生 code_action 获取当前选区。
  -- 即使只有一个重构，也先显示列表确认，避免按 Ra 直接改代码。
  request("refactor", false)
end

return M
