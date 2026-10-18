-- 输入几何共用；Snacks 每次开窗求值，Noice 只接受加载时的数字。
local M = {}

M.max_width = 80

M.reserved = 6

function M.width()
  return math.max(30, math.min(M.max_width, vim.o.columns - M.reserved))
end

function M.noice_min_width()
  return math.max(26, M.width() - 4)
end

function M.center_row()
  return math.floor((vim.o.lines - 3) / 2)
end

return M
