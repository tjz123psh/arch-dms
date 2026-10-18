-- Neovide GUI 专用配置

if not vim.g.neovide then
  return
end

vim.g.neovide_scale_factor = 1.0

vim.g.neovide_opacity = 0.80

vim.g.neovide_cursor_vfx_mode = "railgun"

local font = "JetBrainsMono Nerd Font:h12"
if vim.fn.has("linux") == 1 and vim.fn.executable("fc-match") == 1 then
  local matched = vim.fn.systemlist({ "fc-match", "JetBrainsMono Nerd Font" })[1] or ""
  if not matched:lower():find("jetbrains", 1, true) then
    font = "monospace:h12"
  end
end
vim.o.guifont = font

vim.g.neovide_refresh_rate = 144

vim.g.neovide_corner_preference = "round"

vim.g.neovide_cursor_short_animation_length = 0.13

local function change_scale(delta)
  local current = vim.g.neovide_scale_factor or 1.0
  local next_scale = current + delta
  next_scale = math.min(3.0, math.max(0.5, next_scale))
  vim.g.neovide_scale_factor = next_scale
end

local map = vim.keymap.set
map("n", "<C-=>", function()
  change_scale(0.1)
end, { desc = "Neovide 放大" })
map("n", "<C-->", function()
  change_scale(-0.1)
end, { desc = "Neovide 缩小" })
map("n", "<C-0>", function()
  vim.g.neovide_scale_factor = 1.0
end, { desc = "Neovide 重置缩放" })

local OPACITY_STEPS = {
  { 1.00, "1.00 —— 完全不透明" },
  { 0.95, "0.95" },
  { 0.90, "0.90" },
  { 0.85, "0.85" },
  { 0.80, "0.80 —— 出厂默认" },
  { 0.70, "0.70" },
  { 0.60, "0.60" },
  { 0.50, "0.50 —— 最透（字会开始不好认）" },
}

local STATE_FILE = vim.fs.joinpath(vim.fn.stdpath("state"), "neovide-opacity")

local function load_saved_opacity()
  local f = io.open(STATE_FILE, "r")
  if not f then
    return nil
  end
  local raw = f:read("*l")
  f:close()
  local n = tonumber(raw)
  if not n or n < 0 or n > 1 then
    return nil -- 文件被改坏就当没存过，别把非法值喂给 Neovide
  end
  return n
end

local function save_opacity(value)
  local f, err = io.open(STATE_FILE, "w")
  if not f then
    vim.notify("不透明度已生效，但保存失败：" .. tostring(err), vim.log.levels.WARN)
    return
  end
  f:write(string.format("%.2f\n", value))
  f:close()
end

local function current_opacity()
  return load_saved_opacity() or vim.g.neovide_opacity or 1.0
end

do
  local saved = load_saved_opacity()
  if saved then
    vim.g.neovide_opacity = saved
  end
end

local function pick_opacity()
  local original = current_opacity()
  local items = {}
  for _, s in ipairs(OPACITY_STEPS) do
    items[#items + 1] = { value = s[1], label = s[2] }
  end
  local has_current = false
  for _, it in ipairs(items) do
    if math.abs(it.value - original) < 0.001 then
      has_current = true
      break
    end
  end
  if not has_current then
    table.insert(items, 1, { value = original, label = string.format("%.2f —— 当前值", original) })
  end

  vim.ui.select(items, {
    prompt = "不透明度（回车确认，Esc 取消）",
    format_item = function(it)
      local mark = math.abs(it.value - original) < 0.001 and "● " or "  "
      return mark .. it.label
    end,
  }, function(choice)
    local target = choice and choice.value or original
    vim.g.neovide_opacity = target
    if choice and math.abs(target - original) > 0.001 then
      save_opacity(target) -- 选一次就定下来：写文件，下次启动自动套用
      vim.notify(
        string.format("不透明度 = %.2f（已记住，重启后仍是这个值）", target),
        vim.log.levels.INFO
      )
    end
  end)
end

map("n", "<leader>uo", pick_opacity, { desc = "Neovide 不透明度（选择框）" })
