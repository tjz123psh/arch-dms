-- 项目列表：最近顺序、最长根置顶、显示与确认；不持有历史写策略。
local M = {}
function M.show()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    pcall(lazy.load, { plugins = { "project.nvim", "neo-tree.nvim", "snacks.nvim" } })
  end

  local ok_snacks, Snacks = pcall(require, "snacks")
  if not ok_snacks then
    vim.notify("项目列表加载失败（snacks 不可用）", vim.log.levels.ERROR)
    return
  end

  local projects = require("core.projects.history").list()
  for i = 1, math.floor(#projects / 2) do
    projects[i], projects[#projects - i + 1] = projects[#projects - i + 1], projects[i]
  end

  local current
  local cwd, best, best_len = vim.fn.getcwd(), nil, 0
  for i, dir in ipairs(projects) do
    if (cwd == dir or cwd:sub(1, #dir + 1) == dir .. "/") and #dir > best_len then
      best, best_len = i, #dir
    end
  end
  if best then
    current = table.remove(projects, best)
    table.insert(projects, 1, current)
  end

  if #projects == 0 then
    vim.notify("暂无项目历史", vim.log.levels.INFO)
    return
  end

  local home = vim.fn.expand("~")
  local function pretty_path(path)
    if path == home then
      return "~"
    end
    return (path:gsub("^" .. vim.pesc(home) .. "/", "~/"))
  end

  local items = {}
  local name_width = 0
  for _, dir in ipairs(projects) do
    local name = vim.fn.fnamemodify(dir, ":t")
    local parent = pretty_path(vim.fn.fnamemodify(dir, ":h"))
    name_width = math.max(name_width, vim.fn.strdisplaywidth(name))
    local text = name .. "  " .. dir
    items[#items + 1] = {
      text = text,
      project_dir = dir,
      project_name = name,
      project_parent = parent,
      project_current = dir == current,
    }
  end
  name_width = math.min(name_width, 24) -- 名字列上限：够放下常见长名（列对齐），又不至于把路径挤没

  -- 尺寸：紧凑预设只有 55% 宽 / 40% 高，项目列表显得太小；这里按屏幕比例放大，
  -- 同时保证最长的一行（名字 + 路径）不会被截断。
  local window_width = (function()
    local widest = 0
    for _, item in ipairs(items) do
      local name = vim.fn.strdisplaywidth(item.project_name or "")
      local parent = vim.fn.strdisplaywidth(item.project_parent or "")
      local badge = item.project_current and 6 or 0 -- "  当前" = 2 空格 + 4 列
      widest = math.max(widest, 2 + math.max(name, name_width) + 2 + parent + badge)
    end
    local content = math.min(96, widest + 4, vim.o.columns - 4)
    local wide = math.min(160, math.floor(vim.o.columns * 0.8), vim.o.columns - 4)
    return math.max(40, wide, content)
  end)()
  local window_rows = math.min(math.max(math.floor(vim.o.lines * 0.6), 8), vim.o.lines - 4)

  Snacks.picker.pick({
    source = "project-history",
    title = " 项目 ",
    items = items,
    format = function(item)
      local name = item.project_name or vim.fn.fnamemodify(item.project_dir or "", ":t")
      local icon, icon_hl = Snacks.util.icon(name, "directory", { fallback = { dir = "󰉋 " } })
      local pad = string.rep(" ", math.max(0, name_width - vim.fn.strdisplaywidth(name)))
      local line = {
        { icon, icon_hl },
        { name, item.project_current and "SnacksPickerCurrentProject" or "SnacksPickerFile" },
        { pad .. "  ", "SnacksPickerDelim" },
        { item.project_parent or "", "SnacksPickerDir" },
      }
      if item.project_current then
        line[#line + 1] = { "  当前", "SnacksPickerCurrentBadge" }
      end
      return line
    end,
    layout = {
      preset = "picker_compact",
      backdrop = 60,
      layout = {
        width = window_width,
        height = window_rows,
      },
    },
    confirm = function(picker, item)
      picker:close()
      if item == nil then
        return
      end
      -- 本源只接受自己生成的 project_dir，不猜测文件项或显示文本。
      require("core.projects").switch(type(item) == "table" and item.project_dir or nil)
    end,
  })
end
return M
