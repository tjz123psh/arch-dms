-- 中文标点输入即转半角

local M = {}

M.map = {
  ["，"] = ",",
  ["。"] = ".",
  ["、"] = ",",
  ["；"] = ";",
  ["："] = ":",
  ["！"] = "!",
  ["？"] = "?",
  ["（"] = "(",
  ["）"] = ")",
  ["【"] = "[",
  ["】"] = "]",
  ["《"] = "<",
  ["》"] = ">",
  ["「"] = '"',
  ["」"] = '"',
  ["『"] = "'",
  ["』"] = "'",
  ["“"] = '"',
  ["”"] = '"',
  ["‘"] = "'",
  ["’"] = "'",
  ["—"] = "-",
  ["～"] = "~",
  ["…"] = "...",
  ["·"] = ".",
  ["　"] = " ",
}

M.exclude_ft = { markdown = true, text = true, gitcommit = true, help = true }

vim.g.cjk_punct = true -- 默认开启

local function enabled()
  if not vim.g.cjk_punct then
    return false
  end
  return not M.exclude_ft[vim.bo.filetype]
end

-- 必须匹配完整 UTF-8 字符，而非按字节的中文字符类。
local function convert(text)
  return (text:gsub("[\1-\127\194-\244][\128-\191]*", function(c)
    return M.map[c] or c
  end))
end

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = vim.api.nvim_create_augroup("CJKPunct", { clear = true }),
  desc = "全角标点输入即转半角（:CJKPunct 可关）",
  callback = function()
    if not enabled() then
      return
    end
    local repl = M.map[vim.v.char]
    if repl then
      vim.v.char = repl
    end
  end,
})

vim.api.nvim_create_user_command("CJKPunct", function()
  vim.g.cjk_punct = not vim.g.cjk_punct
  vim.notify("中文标点自动转半角：" .. (vim.g.cjk_punct and "已开启" or "已关闭"), vim.log.levels.INFO)
end, { desc = "切换「全角标点输入即转半角」" })

vim.api.nvim_create_user_command("CJKPunctFix", function(cmd)
  local first, last = cmd.line1, cmd.line2
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local changed = 0
  for i, line in ipairs(lines) do
    local new = convert(line)
    if new ~= line then
      lines[i] = new
      changed = changed + 1
    end
  end
  if changed > 0 then
    vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
  end
  vim.notify(string.format("已把 %d 行里的全角标点转成半角", changed), vim.log.levels.INFO)
end, { range = "%", desc = "当前缓冲区/选区的全角标点转半角" })

return M
