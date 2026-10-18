-- nvim -u NONE -i NONE -n --headless -l tests/autosave.lua
-- 每个用例独立进程和临时文件，不操作真实项目。
local root = vim.env.NVIM_TEST_CONFIG or vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local cases = {
  { name = "q-bang", keys = ":q!<CR>" },
  { name = "silent", keys = ":silent q!<CR>" },
  { name = "abbrev", keys = ":qui!<CR>" },
  { name = "short", keys = ":qu!<CR>" },
  { name = "count-modifier", keys = ":silent! 1q!<CR>" },
  { name = "comment", keys = ':q! " discard<CR>' },
  { name = "qa-bang", keys = ":qa!<CR>", split = true },
  { name = "quitall-alias", keys = ":quita!<CR>", split = true },
  { name = "cq", keys = ":cq<CR>", split = true, exit = 1 },
  { name = "cqu", keys = ":cqu<CR>", exit = 1 },
  { name = "cq-zero", keys = ":0cq<CR>" },
  { name = "zq", keys = "ZQ" },
  { name = "normal-q", keys = ":q<CR>", saved = true },
  { name = "normal-qa", keys = ":qa<CR>", split = true, saved = true },
  { name = "wq-bang", keys = ":wq!<CR>", saved = true },
  { name = "x-bang", keys = ":x!<CR>", saved = true },
  { name = "zz", keys = "ZZ", saved = true },
  { name = "cancel-esc", keys = ":q!<Esc>", post = "focus", saved = true },
  { name = "cancel-ctrlc", keys = ":q!<C-c>", post = "focus", saved = true },
  { name = "search", keys = "/modified<CR>", post = "focus", saved = true },
  { name = "invalid-exit", keys = ":q! unexpected<CR>", post = "focus", saved = true },
  { name = "sticky-q", keys = ":q!<CR>", split = true, post = "focus", saved = true, discard_right = true },
  { name = "sticky-zq", keys = "ZQ", split = true, post = "focus", saved = true, discard_right = true },
  { name = "sticky-buffer", keys = ":q!<CR>", split = true, post = "buffer", saved = true, discard_right = true },
  { name = "prefix-chain", keys = ":echo 1 | q!<CR>" },
  { name = "discard-save-chain", keys = ":q! | q<CR>", split = true, saved = true, discard_right = true },
  { name = "save-discard-chain", keys = ":q | q!<CR>", split = true, saved = true },
  { name = "yielding-quit", keys = ":q!<CR>", yielding = true },
  { name = "yielding-zq", keys = "ZQ", yielding = true },
  { name = "failed-zq", fail_quit = true, post = "focus", saved = true },
  { name = "idle-clears-invalid-intent", keys = ":q! unexpected<CR>", post = "safe-quit", saved = true },
}
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end
if vim.env.NVIM_AUTOSAVE_CASE then
  local case = cases[tonumber(vim.env.NVIM_AUTOSAVE_CASE)]
  local dir = assert(vim.env.NVIM_AUTOSAVE_FIXTURE)
  require("core.keymaps")
  require("core.autocmds")
  vim.g.core_autosave = false
  vim.fn.writefile({ "original" }, dir .. "/left.txt")
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/left.txt"))
  local left = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(left, 0, -1, false, { "modified" })
  if case.split then
    vim.fn.writefile({ "original" }, dir .. "/right.txt")
    vim.cmd.vsplit(vim.fn.fnameescape(dir .. "/right.txt"))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "modified" })
  end
  vim.g.core_autosave = true
  if case.yielding then
    vim.api.nvim_create_autocmd("QuitPre", {
      once = true,
      callback = function()
        vim.wait(30, function()
          return false
        end, 5)
      end,
    })
  end
  if case.fail_quit then
    local native_quit = vim.cmd.quit
    vim.cmd.quit = function()
      error("test quit rejected")
    end
    local ok = pcall(vim.fn.maparg("ZQ", "n", false, true).callback)
    vim.cmd.quit = native_quit
    assert(not ok, "wrapper must propagate quit failure")
  else
    press(case.keys)
  end
  assert(case.post, "exit command unexpectedly returned: " .. case.name)
  if case.split then
    assert(#vim.api.nvim_list_wins() == 1, "ZQ/q! must close only one window")
  end
  if case.post == "safe-quit" then
    vim.api.nvim_exec_autocmds("SafeState", {})
    vim.cmd.quit()
    error("normal quit should exit")
  end
  if case.post == "buffer" then
    vim.cmd.enew()
  else
    vim.api.nvim_exec_autocmds("FocusLost", {})
  end
  vim.g.core_autosave = false
  vim.cmd("qa!")
  return
end
local base = vim.fn.tempname()
vim.fn.mkdir(base, "p")
local script = root .. "/tests/autosave.lua"
local passed = 0
for i, case in ipairs(cases) do
  local dir = base .. "/" .. case.name
  vim.fn.mkdir(dir, "p")
  local full_data = vim.env.NVIM_AUTOSAVE_FULL_DATA
  local cmd = full_data
      and { vim.v.progpath, "-i", "NONE", "-n", "--headless", "-c", "luafile " .. vim.fn.fnameescape(script) }
    or { vim.v.progpath, "-u", "NONE", "-i", "NONE", "-n", "--headless", "-l", script }
  local result = vim
    .system(cmd, {
      cwd = root,
      text = true,
      timeout = 10000,
      env = {
        NVIM_AUTOSAVE_CASE = tostring(i),
        NVIM_AUTOSAVE_FIXTURE = dir,
        XDG_STATE_HOME = dir .. "/state",
        XDG_DATA_HOME = full_data or (dir .. "/data"),
        XDG_CACHE_HOME = dir .. "/cache",
      },
    })
    :wait()
  assert(result.code == (case.exit or 0), case.name .. ": " .. (result.stderr or ""))
  local expected = case.saved and "modified" or "original"
  assert(vim.fn.readfile(dir .. "/left.txt")[1] == expected, case.name .. " left disk mismatch; " .. dir)
  if case.split then
    local right_expected = case.discard_right and "original" or expected
    assert(vim.fn.readfile(dir .. "/right.txt")[1] == right_expected, case.name .. " right disk mismatch; " .. dir)
  end
  passed = passed + 1
end
print("PASS " .. passed .. " isolated autosave/quit cases")
vim.cmd("qa!")
