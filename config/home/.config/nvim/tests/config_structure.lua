-- nvim -u NONE -i NONE -n --headless -l tests/config_structure.lua
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local count = 0
local function check(ok, message)
  assert(ok, message)
  count = count + 1
end
for _, path in ipairs({
  "core/ui.lua",
  "core/input_boxes.lua",
  "core/cheatsheet.lua",
  "core/projects.lua",
  "neovide.lua",
}) do
  check(not vim.uv.fs_stat(root .. "/lua/" .. path), "retired entry shadows new directory: " .. path)
end
for _, path in ipairs({
  "core/ui/init.lua",
  "core/ui/input.lua",
  "core/ui/reference.lua",
  "core/ui/cheatsheet.lua",
  "core/ui/neovide.lua",
  "core/projects/init.lua",
  "core/projects/history.lua",
  "core/projects/picker.lua",
  "core/movement.lua",
}) do
  check(loadfile(root .. "/lua/" .. path) ~= nil, "module syntax: " .. path)
end
require("core.projects")
require("core.ui")
check(not package.loaded["core.projects.picker"], "project setup must not eagerly load picker")
check(not package.loaded["core.ui.reference"], "UI setup must not eagerly load guide data")
check(not package.loaded.snacks and not package.loaded.project_nvim, "shared modules do not start plugins")
local mason = assert(loadfile(root .. "/lua/plugins/mason.lua"))()
local installer = assert(loadfile(root .. "/lua/plugins/mason-tool-installer.lua"))()
check(mason.dependencies == nil, "Mason must not depend back on its tool installer")
check(installer.dependencies[1] == "williamboman/mason.nvim", "tool installer initializes Mason first")
local seen = {}
for _, path in ipairs({ "sidekick.lua", "terminal.lua", "dap/init.lua" }) do
  local spec = assert(loadfile(root .. "/lua/plugins/" .. path))()
  for _, key in ipairs(spec.keys) do
    check(type(key[2]) == "function", path .. " must own the actual lazy callback")
    check(not seen[key[1]], "duplicate key: " .. key[1])
    seen[key[1]] = true
  end
end
local text = table.concat(vim.fn.readfile(root .. "/lua/core/ui/neovide.lua"), "\n")
check(text:find("neovide_refresh_rate = 144", 1, true) ~= nil, "preserve user refresh rate")
print("PASS " .. count .. " configuration structure assertions")
vim.cmd("qa!")
