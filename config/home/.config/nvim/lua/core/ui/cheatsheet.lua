-- 快捷键速查浮窗（<leader>hk / :CheatSheet）

local M = {}
local ns = vim.api.nvim_create_namespace("core_cheatsheet")

local state = {
  win = nil,
}

local sections = require("core.ui.reference")

local function define_highlights()
  vim.api.nvim_set_hl(0, "CheatSheetTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetHint", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetSection", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetSeparator", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetKey", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetText", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetBg", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetBorder", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetWinTitle", { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetBar", { link = "Comment", default = true })
end

local function pad_right(text, width)
  local padding = width - vim.fn.strdisplaywidth(text)
  if padding <= 0 then
    return text
  end
  return text .. string.rep(" ", padding)
end

local function close_existing()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
    return true
  end
  return false
end

function M.show()
  if close_existing() then
    return
  end

  define_highlights()

  local lines = {}
  local marks = {}
  local key_marks = {}

  local available_width = math.max(1, vim.o.columns - 4)
  local width = math.min(84, available_width)
  local body_width = math.max(1, width - 4)
  local key_width = math.min(24, math.max(12, math.floor(body_width * 0.4)))

  local function add(line, hl)
    table.insert(lines, line)
    if hl then
      marks[#lines - 1] = hl
    end
  end

  local function add_mark(row_idx, start_col, end_col, hl)
    table.insert(key_marks, { row = row_idx, start_col = start_col, end_col = end_col, hl = hl })
  end

  do
    local head = "  ▍ 常用快捷键"
    local hint = "j/k 滚动 · q / Esc 关闭  "
    add(pad_right(head, body_width - vim.fn.strdisplaywidth(hint)) .. hint)
    add_mark(0, 0, #head, "CheatSheetTitle")
    add_mark(0, #lines[1] - #hint, #lines[1], "CheatSheetHint")
  end
  add("  " .. string.rep("─", body_width), "CheatSheetSeparator")

  for _, sec in ipairs(sections) do
    add("")
    add("  ▍ " .. sec[1])
    add_mark(#lines - 1, 2, 5, "CheatSheetBar") -- "  ▍" 的 ▍（3 字节）
    add_mark(#lines - 1, 5, #lines[#lines], "CheatSheetSection")
    for _, item in ipairs(sec[2]) do
      local key = item[1]
      local line = "    " .. pad_right(key, key_width) .. item[2]
      add(line, "CheatSheetText")
      add_mark(#lines - 1, 4, 4 + #key, "CheatSheetKey")
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local available_height = math.max(1, vim.o.lines - 4)
  local height = math.min(#lines, available_height)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local title = width >= 32 and " 快捷键速查  <leader>hk " or " 快捷键 "
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = row,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  state.win = win

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for row_idx, hl in pairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, row_idx, 0, {
      end_col = #lines[row_idx + 1],
      hl_group = hl,
    })
  end
  for _, mark in ipairs(key_marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mark.row, mark.start_col, {
      end_col = mark.end_col,
      hl_group = mark.hl,
    })
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "cheatsheet"
  vim.wo[win].winhl = "NormalFloat:CheatSheetBg,FloatBorder:CheatSheetBorder,FloatTitle:CheatSheetWinTitle"
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

return M
