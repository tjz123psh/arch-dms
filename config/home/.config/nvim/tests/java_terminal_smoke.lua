-- 在隔离目录中启动短命测试 shell，验证真实 toggleterm；不启动 Java/Maven/Gradle。
local temp = assert(vim.env.NVIM_JAVA_TEST_TMP, "set NVIM_JAVA_TEST_TMP to an isolated directory")
assert(temp:match("^/tmp/nvim%-java%-"), "temporary test directory required")
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.opt.rtp:append(vim.env.HOME .. "/.local/share/nvim/lazy/toggleterm.nvim")
vim.o.shell = "/bin/bash"
require("toggleterm").setup({ start_in_insert = false, close_on_exit = false })
local terminals = require("languages.java.terminal")
local created = {}
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
end
local function wait(predicate, label)
  check(vim.wait(4000, predicate, 20), label)
end
local function get(project, kind, main)
  local dir = temp .. "/" .. project
  vim.fn.mkdir(dir, "p")
  local term = terminals.get(dir, kind, main)
  created[#created + 1] = term
  return term
end
local ok, err = xpcall(function()
  local a = get("a", "spring", "App")
  local b = get("b", "spring", "App")
  local build = get("a", "build")
  check(a.id > 3 and b.id ~= a.id and build.id ~= a.id, "distinct reserved identities")
  terminals.run(a, "printf 'Started AppA\n'; sleep 30", true)
  wait(function()
    return not a._java_dispatching and terminals.busy(a)
  end, "A process running")
  terminals.run(b, "printf 'Started AppB\n'; sleep 30", true)
  wait(function()
    return not b._java_dispatching and terminals.busy(b)
  end, "B process running")
  terminals.run(build, "printf 'TEST_DONE\n'", false)
  wait(function()
    return not terminals.busy(build) and (build._java_output or ""):find("TEST_DONE", 1, true)
  end, "build runs while apps live")
  check(terminals.busy(a) and terminals.busy(b), "build did not stop apps")
  a:close()
  check(terminals.get(a._java_root, "spring", "App") == a, "closed window retains owned shell")
  terminals.run(a, "printf 'Started RestartA\n'; sleep 30", true)
  wait(function()
    return not a._java_restarting
      and not a._java_dispatching
      and terminals.busy(a)
      and (a._java_output or ""):find("Started RestartA", 1, true)
  end, "restart waits then starts new command")
  check(terminals.busy(b), "restart A leaves B alive")
  check(not (a._java_output or ""):find("Started AppA", 1, true), "old output not used for new readiness")
  build:send("exit", false)
  wait(function()
    return vim.fn.jobwait({ build.job_id }, 0)[1] ~= -1
  end, "build shell exited")
  local old_buffer = build.bufnr
  local replacement = get("a", "build")
  check(replacement ~= build and replacement.id ~= build.id, "dead shell gets new object")
  check(vim.api.nvim_buf_is_valid(old_buffer), "keep old terminal output buffer")
  build = replacement
  terminals.run(build, "sleep 30", false)
  wait(function()
    return not build._java_dispatching and terminals.busy(build)
  end, "long build busy")
  check(terminals.run(build, "printf SHOULD_NOT_RUN", false) == false, "busy build rejected")
end, debug.traceback)
-- 只停止本脚本创建的测试终端，不枚举或干预用户终端。
for _, term in ipairs(created) do
  if term.job_id then
    pcall(vim.fn.chansend, term.job_id, string.char(3))
  end
end
vim.wait(2000, function()
  for _, term in ipairs(created) do
    if terminals.busy(term) then
      return false
    end
  end
  return true
end, 20)
for _, term in ipairs(created) do
  if term.job_id then
    pcall(vim.fn.jobstop, term.job_id)
    vim.fn.jobwait({ term.job_id }, 1000)
  end
end
assert(ok, err)
print("PASS " .. checks .. " real terminal assertions; all test jobs stopped")
vim.cmd("qa!")
