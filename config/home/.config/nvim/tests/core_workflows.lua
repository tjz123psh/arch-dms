-- nvim -u NONE -i NONE -n --headless -l tests/core_workflows.lua
package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
vim.g.mapleader = " "
vim.g.core_autosave = false
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end
local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local function fixture(text)
  press("<Esc>")
  vim.cmd("enew!")
  vim.bo.undolevels = -1
  vim.api.nvim_buf_set_lines(0, 0, -1, false, text)
  vim.bo.undolevels = 1000
  vim.bo.filetype = "text"
  vim.bo.indentexpr, vim.bo.cindent = "", false
  vim.o.equalprg, vim.o.lisp = "", false
end
require("core.keymaps")
check(not package.loaded["core.ui.reference"], "global keys must not eagerly load the large guide")
fixture({ "one", "  two", "    three", "four" })
vim.api.nvim_win_set_cursor(0, { 2, 2 })
press("3J")
check(vim.deep_equal(lines(), { "one", "    three", "four", "  two" }), "normal count and lower boundary")
check(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 4, 2 }), "normal cursor column")
press("3K")
check(vim.deep_equal(lines(), { "  two", "one", "    three", "four" }), "normal upper boundary")
vim.bo.modifiable = false
local before = lines()
press("J")
check(vim.deep_equal(lines(), before), "unmodifiable buffer movement is a no-op")
vim.bo.modifiable = true
for _, mode in ipairs({ "V", "v", "<C-v>", "V<C-g>" }) do
  fixture({ "aaa", "  bbb", "    ccc", "ddd" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  press(mode == "V<C-g>" and "Vj<C-g>J" or mode .. "jJ")
  check(vim.deep_equal(lines(), { "aaa", "ddd", "  bbb", "    ccc" }), mode .. " preserves text indentation")
  check(
    vim.fn.mode():match("[vVsS]") ~= nil or vim.fn.mode() == "\22" or vim.fn.mode() == "\19",
    mode .. " restores selection"
  )
  press("K")
  check(vim.deep_equal(lines(), { "aaa", "  bbb", "    ccc", "ddd" }), mode .. " allows consecutive movement")
end
fixture({ "a", "bb", "ccc", "d" })
vim.api.nvim_win_set_cursor(0, { 3, 1 })
press("vkJ")
check(vim.deep_equal(lines(), { "a", "d", "bb", "ccc" }), "reverse visual selection moves the intended lines")
press("<Esc>")
require("core.cjk_punct")
fixture({ "，一", "二。", "三！" })
vim.cmd("2CJKPunctFix")
check(
  vim.deep_equal(lines(), { "，一", "二.", "三！" }),
  "single-address conversion does not rewrite the whole buffer"
)
vim.cmd.CJKPunctFix()
check(vim.deep_equal(lines(), { ",一", "二.", "三!" }), "default conversion covers the whole buffer")
fixture({ "（一）", "【二】", "《三》" })
vim.cmd("1,2CJKPunctFix")
check(vim.deep_equal(lines(), { "(一)", "[二]", "《三》" }), "explicit range conversion")
local enabled = vim.g.cjk_punct
vim.cmd.CJKPunct()
check(vim.g.cjk_punct ~= enabled, "punctuation toggle")
vim.cmd.CJKPunct()

local calls = {}
local function record(name)
  return function(...)
    calls[#calls + 1] = { name = name, args = { ... } }
  end
end
local cli = {}
for _, name in ipairs({ "toggle", "select", "send", "close", "focus" }) do
  cli[name] = record(name)
end
package.loaded["sidekick.cli"] = nil
local loaded = 0
package.preload["sidekick.cli"] = function()
  loaded = loaded + 1
  return cli
end
local sidekick = assert(loadfile("lua/plugins/sidekick.lua"))()
check(loaded == 0, "Sidekick declaration is lazy")
for _, key in ipairs(sidekick.keys) do
  key[2]()
end
check(#calls == 5 and loaded == 1, "one callback per Sidekick key")
check(calls[1].name == "toggle" and calls[4].name == "close", "hide and terminate remain different actions")
check(calls[2].args[1].filter.installed and calls[3].args[1].msg == "{this}", "Sidekick selector and context")
check(vim.deep_equal(sidekick.keys[3].mode, { "n", "x" }), "context visual mode")
check(vim.deep_equal(sidekick.keys[5].mode, { "n", "t", "i", "x" }), "focus modes")

calls = {}
package.loaded.toggleterm = { toggle = record("terminal") }
local term = assert(loadfile("lua/plugins/terminal.lua"))()
local ordinary = vim.api.nvim_get_current_win()
local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
  relative = "editor",
  row = 1,
  col = 1,
  width = 20,
  height = 3,
})
term.keys[2][2]()
check(vim.api.nvim_get_current_win() == ordinary, "split action leaves a floating window first")
vim.api.nvim_win_close(float, true)
term.keys[1][2]()
vim.o.columns = 80
term.keys[3][2]()
check(
  calls[1].args[1] == 2 and calls[1].args[2] == 15 and calls[1].args[4] == "horizontal",
  "terminal two remains horizontal"
)
check(calls[2].args[1] == 1 and calls[2].args[4] == "float", "terminal one remains floating")
check(
  calls[3].args[1] == 3 and calls[3].args[2] == 36 and calls[3].args[4] == "vertical",
  "terminal three remains adaptive"
)
check(term.opts.close_on_exit == false, "finished output is retained")

calls = {}
local dap = {}
for _, name in ipairs({
  "continue",
  "toggle_breakpoint",
  "step_over",
  "step_into",
  "step_out",
  "run_last",
  "list_breakpoints",
  "set_breakpoint",
  "clear_breakpoints",
}) do
  dap[name] = record(name)
end
package.loaded.dap = dap
local debug = assert(loadfile("lua/plugins/dap/init.lua"))()
local input = vim.fn.input
vim.fn.input = function()
  return ""
end
debug.keys[8][2]()
debug.keys[9][2]()
check(#calls == 0, "cancelled conditional/log breakpoints do nothing")
vim.fn.input = function()
  return "value"
end
for _, key in ipairs(debug.keys) do
  key[2]()
end
vim.fn.input = input
check(#calls == 10, "one action for each DAP key")
check(calls[7].name == "list_breakpoints" and calls[7].args[1], "breakpoint list opens")
check(calls[8].args[1] == "value" and calls[9].args[3] == "value", "conditional and logpoint arguments")

-- Bootstrap failures preserve existing directories and never invoke rm.
for _, scenario in ipairs({ "ready", "missing", "broken", "clone-failed", "rename-failed", "collision" }) do
  local system, renamed, configured = {}, 0, 0
  local config
  local fake = {
    v = { shell_error = scenario == "clone-failed" and 1 or 0 },
    fn = {
      stdpath = function()
        return "/fixture"
      end,
      getpid = function()
        return 42
      end,
      system = function(args)
        system[#system + 1] = args
        return "clone output"
      end,
    },
    uv = {
      fs_stat = function(path)
        if scenario == "ready" and path:match("/init.lua$") then
          return {}
        end
        if scenario ~= "missing" and path == "/fixture/lazy/lazy.nvim" then
          return {}
        end
      end,
      fs_lstat = function()
        return scenario == "collision" and {} or nil
      end,
      fs_rename = function()
        renamed = renamed + 1
        return scenario ~= "rename-failed", "fixture error"
      end,
    },
    opt = { rtp = { prepend = function() end } },
  }
  local loader = assert(loadfile("lua/core/lazy.lua"))
  setfenv(
    loader,
    setmetatable({
      vim = fake,
      require = function(name)
        assert(name == "lazy")
        return {
          setup = function(opts)
            configured = configured + 1
            config = opts
          end,
        }
      end,
    }, { __index = _G })
  )
  local ok = pcall(loader)
  local success = scenario == "ready" or scenario == "missing" or scenario == "broken"
  check(ok == success and configured == (success and 1 or 0), "bootstrap outcome " .. scenario)
  for _, args in ipairs(system) do
    check(args[1] == "git", "bootstrap never deletes a directory")
  end
  if scenario == "broken" then
    check(renamed == 1, "incomplete installation preserved by rename")
  end
  if config then
    check(config.checker.enabled == false, "automatic update checker remains disabled")
  end
end

print("PASS " .. checks .. " core editing/lazy-action assertions")
vim.cmd("qa!")
