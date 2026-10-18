-- nvim -u NONE -i NONE -n --headless -l tests/whichkey_scopes.lua
-- 真实 which-key + 代表性键位，不启动 LSP、DAP、项目向导或其它插件。
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.opt.rtp:append(vim.env.HOME .. "/.local/share/nvim/lazy/which-key.nvim")
vim.g.mapleader = " "
local count = 0
local function eq(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. "\n" .. vim.inspect(actual))
  count = count + 1
end
local noop = function() end
for _, key in ipairs({ "e", "j", "q", "F", "aa", "bd", "ff", "hk", "sp", "tt", "vh", "wq", "Gc", "Mp", "dl" }) do
  vim.keymap.set("n", "<leader>" .. key, noop, { desc = "fixture " .. key })
end
local buffers = {}
for _, ft in ipairs({ "java", "go", "rust", "c", "cpp", "lua", "markdown", "text" }) do
  local b = vim.api.nvim_create_buf(true, false)
  buffers[ft] = b
  vim.bo[b].filetype = ft
  if ft ~= "markdown" and ft ~= "text" then
    require("languages.shared.lsp")({}, b)
  end
  if ft == "java" then
    for _, key in ipairs({ "Jr", "Jt", "ot", "Rv", "mc", "co", "sr" }) do
      vim.keymap.set("n", "<leader>" .. key, noop, { buffer = b, desc = "fixture " .. key })
    end
    vim.keymap.set("x", "<leader>Rv", noop, { buffer = b, desc = "fixture visual Rv" })
  end
end
local function snapshot()
  local out = {}
  local function add(scope, maps)
    for _, m in ipairs(maps) do
      if not (m.desc or ""):find("which-key-trigger", 1, true) then
        out[scope .. m.lhs] = { rhs = m.rhs, callback = m.callback, desc = m.desc, expr = m.expr, noremap = m.noremap }
      end
    end
  end
  for _, mode in ipairs({ "n", "x", "s" }) do
    add("global:" .. mode .. ":", vim.api.nvim_get_keymap(mode))
    for ft, b in pairs(buffers) do
      add(ft .. ":" .. mode .. ":", vim.api.nvim_buf_get_keymap(b, mode))
    end
  end
  return out
end
local before = snapshot()
local spec = dofile(root .. "/lua/plugins/whichkey.lua")
require("which-key").setup(spec.opts)
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(
  vim.wait(1000, function()
    return require("which-key.config").loaded
  end, 10),
  "which-key not loaded"
)
local function tree(ft, mode)
  vim.api.nvim_set_current_buf(buffers[ft])
  return require("which-key.buf").get({ buf = buffers[ft], mode = mode or "n", update = true }).tree
end
local function label(t, key)
  local node = t:find(" " .. key)
  return node and node.desc or nil
end
for _, ft in ipairs({ "java", "go", "rust", "c", "cpp", "lua", "markdown", "text" }) do
  local t = tree(ft)
  eq(label(t, "f"), "通用 · 搜索", ft .. " generic group")
  eq(label(t, "d"), "DAP · 调试", ft .. " cross-language debugger")
  eq(label(t, "s"), "Spring · 项目/运行", ft .. " global wizard remains visible")
  eq(label(t, "G"), "Java · 代码生成", ft .. " global Java generator clearly labeled")
  eq(label(t, "M"), "Markdown · 美化", ft .. " guarded global Markdown action labeled")
  eq(label(t, "F"), "格式化 · 当前文件", ft .. " formatting distinguished")
  eq(label(t, "u"), nil, ft .. " empty Neovide group hidden")
  local language_buffer = ft ~= "markdown" and ft ~= "text"
  eq(label(t, "o"), language_buffer and "整理 · 按语言" or nil, ft .. " shared organization scope")
  eq(label(t, "R"), language_buffer and "重构 · 按语言" or nil, ft .. " shared refactor scope")
  if language_buffer then
    eq(label(t, "Ra"), "可用重构（按语言，支持选区）", ft .. " shared refactor menu action")
  end
  if ft ~= "java" then
    for _, key in ipairs({ "J", "m" }) do
      eq(label(t, key), nil, ft .. " no empty Java-only " .. key)
    end
  end
end
local java = tree("java")
eq(label(java, "o"), "整理 · 按语言", "Java uses shared organization group")
eq(label(java, "R"), "重构 · 按语言", "Java refactoring labeled")
eq(label(java, "J"), "Java · 运行/测试/调试", "Java workflows distinct from generic DAP")
eq(label(java, "Jr"), "fixture Jr", "single-file runner visible in Java menu")
eq(label(java, "m"), "Java · Maven/Gradle", "build tools not universal")
eq(label(java, "c"), "LSP · 代码操作", "shared LSP action")
eq(label(java, "r"), "LSP · 重命名", "shared rename")
local visual = tree("java", "x")
eq(label(visual, "R"), "重构 · 按语言", "visual Java refactoring labeled")
eq(label(visual, "e"), nil, "no fabricated visual filetree action")
eq(label(visual, "F"), nil, "no fabricated visual format action")
eq(label(tree("go", "x"), "R"), "重构 · 按语言", "visual Go refactor group")
eq(label(tree("go", "x"), "Rv"), nil, "Java direct extraction not fabricated for Go")
eq(snapshot(), before, "real key mappings unchanged")
vim.keymap.set("n", "<leader>uo", noop, { desc = "fixture Neovide opacity" })
eq(label(tree("text"), "u"), "Neovide · 显示", "Neovide group follows real mapping")
vim.keymap.del("n", "<leader>uo")
local guide = require("core.ui.cheatsheet")
guide.show()
local guide_width = vim.api.nvim_win_get_width(0)
local legend = false
for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
  if line:find("菜单分类", 1, true) then
    legend = true
  end
  if line:find("行操作", 1, true) then
    break
  end
  if legend then
    eq(vim.fn.strdisplaywidth(line) <= guide_width, true, "legend fits shortcut guide")
  end
end
guide.show()
print("PASS " .. count .. " which-key scope assertions")
if vim.env.NVIM_MENU_PREVIEW == "1" then
  vim.api.nvim_set_current_buf(buffers["java"])
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "// Java menu preview; no language server is running." })
  vim.cmd("set nomodified")
  vim.defer_fn(function()
    print("MENU_READY") -- 等启动后的 BufEnter/触发器安装完成，再由 PTY 注入按键。
  end, 200)
  return -- 由外部 PTY 发送空格、Esc；不自动执行任何映射。
end
vim.cmd("qa!")
