-- 诊断显示与 LSP 日志管理

local M = {}

-- virtual_lines 不折行：按显示宽度换行，箭头行保持原状，最多 12 行。
local function wrap_message(text, width)
  local out = {}
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    local trimmed = vim.trim(para)
    if trimmed ~= "" and trimmed:match("^[%^~]+$") then
      out[#out + 1] = para
      goto continue
    end
    local indent = para:match("^(%s*)") or ""
    local avail = math.max(10, width - vim.fn.strdisplaywidth(indent))
    local line, line_w = "", 0
    for _, word in ipairs(vim.split(para, "%s+", { trimempty = true })) do
      local word_w = vim.fn.strdisplaywidth(word)
      if line_w > 0 and line_w + 1 + word_w > avail then
        out[#out + 1] = indent .. line
        line, line_w = "", 0
      end
      if word_w > avail then -- 超长 token（长包名 / 长签名）硬断
        for _, ch in ipairs(vim.fn.split(word, "\\zs")) do
          local cw = vim.fn.strdisplaywidth(ch)
          if line_w + cw > avail and line_w > 0 then
            out[#out + 1] = indent .. line
            line, line_w = "", 0
          end
          line, line_w = line .. ch, line_w + cw
        end
      else
        if line_w > 0 then
          line, line_w = line .. " ", line_w + 1
        end
        line, line_w = line .. word, line_w + word_w
      end
    end
    if line_w > 0 then
      out[#out + 1] = indent .. line
    end
    ::continue::
  end
  if #out > 12 then -- 超长消息别把整屏占满；按 ]d 弹的浮窗里仍是完整的
    out = vim.list_slice(out, 1, 12)
    out[12] = out[12] .. " …"
  end
  return table.concat(out, "\n")
end

function M.setup()
  vim.api.nvim_create_user_command("LspInfo", function()
    local clients = vim.lsp.get_clients()
    if #clients == 0 then
      vim.notify("没有活跃的 LSP 客户端", vim.log.levels.INFO)
      return
    end
    local lines = {}
    for _, c in ipairs(clients) do
      table.insert(lines, string.format("%s (%s)", c.name, c.id))
      local root = type(c.config.root_dir) == "string" and c.config.root_dir or "N/A"
      table.insert(lines, "  root: " .. root)
      table.insert(lines, "  filetypes: " .. table.concat(c.config.filetypes or {}, ", "))
      table.insert(lines, "")
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP 客户端" })
  end, { force = true, desc = "查看 LSP 客户端状态" })

  vim.api.nvim_create_user_command("LspLog", function()
    vim.cmd.edit(vim.fn.fnameescape(vim.lsp.log.get_filename()))
  end, { force = true, desc = "打开 LSP 日志文件" })

  vim.lsp.log.set_level(vim.log.levels.ERROR)

  do
    local log_path = vim.lsp.log.get_filename()
    local ok, stat = pcall(vim.uv.fs_stat, log_path)
    if ok and stat and stat.size > 5 * 1024 * 1024 then
      pcall(vim.uv.fs_rename, log_path, log_path .. ".1")
    end
  end

  vim.diagnostic.config({
    severity_sort = true,
    virtual_text = {
      spacing = 2,
      prefix = "●",
      source = "if_many",
      current_line = false, -- 当前行改由下面的 virtual_lines 整行显示，避免重复
      severity = { min = vim.diagnostic.severity.WARN }, -- INFO/HINT 只留符号列与下划线，不再占行尾
    },
    virtual_lines = {
      current_line = true, -- 光标所在行：把诊断整行展开在下一行（长消息不再被行尾截断）
      severity = { min = vim.diagnostic.severity.WARN },
      format = function(d)
        local wins = vim.fn.win_findbuf(d.bufnr or 0)
        local win = wins[1] or vim.api.nvim_get_current_win()
        local info = vim.fn.getwininfo(win)[1]
        local textoff = (info and info.textoff) or 0
        local ok, win_w = pcall(vim.api.nvim_win_get_width, win)
        local width = (ok and win_w or vim.o.columns) - textoff - 7 -- 7 = "└──── " 前缀 + 1 余量
        return wrap_message(d.message, math.max(20, width))
      end,
    },
    underline = true, -- 错误范围画波浪线
    signs = true, -- 左侧符号列图标
    float = {
      border = "rounded",
      source = "if_many",
      suffix = function(d)
        local code = d.code and tostring(d.code) or ""
        if code ~= "" and not code:match("^%d+$") then
          return (" [%s]"):format(code)
        end
        return ""
      end,
    },
    update_in_insert = false,
  })

  -- Ctrl-C 不触发 InsertLeave，退出插入模式后补绘可见缓冲区诊断。
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("UserDiagnosticInsertLeaveFallback", { clear = true }),
    pattern = "i*:n*",
    callback = function()
      local done = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        if not done[bufnr] then
          done[bufnr] = true
          vim.diagnostic.show(nil, bufnr)
        end
      end
    end,
    desc = "退出插入模式（含 <C-c>）后补渲染被 update_in_insert=false 隐藏的诊断",
  })
end

return M
