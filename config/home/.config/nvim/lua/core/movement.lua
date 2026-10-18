-- J/K 移动行；保留普通模式与可视/选择模式的不同重缩进语义。
local map = vim.keymap.set

local function move_current_line(direction)
  if not vim.bo.modifiable then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local steps = vim.v.count1

  for _ = 1, steps do
    local line_count = vim.api.nvim_buf_line_count(0)
    if direction > 0 and row >= line_count then
      break
    end
    if direction < 0 and row <= 1 then
      break
    end

    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})

    if direction > 0 then
      vim.api.nvim_buf_set_lines(0, row, row, false, line)
      row = row + 1
    else
      vim.api.nvim_buf_set_lines(0, row - 2, row - 2, false, line)
      row = row - 1
    end
  end

  local moved_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  vim.api.nvim_win_set_cursor(0, { row, math.min(col, #moved_line) })
end

map("n", "J", function()
  move_current_line(1)
end, { desc = "下移当前行", silent = true })
map("n", "K", function()
  move_current_line(-1)
end, { desc = "上移当前行", silent = true })

-- 没有缩进来源的文本不能用 =；equalprg 也不应在移动时启动。
local function can_reindent()
  return vim.o.equalprg == "" and (vim.bo.indentexpr ~= "" or vim.bo.cindent or vim.o.lisp)
end

local function move_visual_lines(direction)
  if not vim.bo.modifiable then
    return
  end

  local vmode = vim.fn.mode(1) -- "v" 字符 / "V" 行 / "\22" 块 / "s"·"S"·"\19" Select
  -- 可视态的旧标记尚未更新，直接记录当前选区及两端列。
  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local anchor_first = anchor[2] <= cursor[2]
  local start_col = anchor_first and anchor[3] or cursor[3]
  local end_col = anchor_first and cursor[3] or anchor[3]

  local first = vim.fn.line("v")
  local last = vim.fn.line(".")
  if first > last then
    first, last = last, first
  end

  local steps = vim.v.count1
  local target
  local delta
  if direction > 0 then
    target = math.min(last + steps, vim.api.nvim_buf_line_count(0))
    delta = target - last
  else
    target = math.max(first - steps - 1, 0)
    delta = target + 1 - first
  end

  if delta == 0 then
    return
  end

  vim.cmd(("silent keepjumps %d,%dmove %d"):format(first, last, target))

  local new_first = first + delta
  local new_last = last + delta

  if can_reindent() then
    vim.cmd(("silent keepjumps %d,%dnormal! =="):format(new_first, new_last))
  end

  vim.cmd("normal! \27")
  local last_line_len = #(vim.api.nvim_buf_get_lines(0, new_last - 1, new_last, false)[1] or "")
  if vmode == "V" then
    vim.fn.setpos("'<", { 0, new_first, 1, 0 })
    vim.fn.setpos("'>", { 0, new_last, 1, 0 })
    vim.api.nvim_win_set_cursor(0, { new_last, 0 })
  else
    vim.fn.setpos("'<", { 0, new_first, start_col, 0 })
    vim.fn.setpos("'>", { 0, new_last, end_col, 0 })
    vim.api.nvim_win_set_cursor(0, { new_last, math.max(0, math.min(end_col - 1, last_line_len)) })
  end
  vim.cmd("normal! gv")
  -- gv 不恢复 Select 子模式，需再切回 Select。
  if vmode == "s" or vmode == "S" or vmode == "\19" then
    vim.cmd("normal! \07")
  end
end

map({ "x", "s" }, "J", function()
  move_visual_lines(1)
end, { desc = "下移选中行", silent = true })
map({ "x", "s" }, "K", function()
  move_visual_lines(-1)
end, { desc = "上移选中行", silent = true })
