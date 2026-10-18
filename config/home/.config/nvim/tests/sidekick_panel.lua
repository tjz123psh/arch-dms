-- 完整配置 + 假 CLI 工具（sleep），不启动任何真实 AI 会话。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-"), "isolated tmp dir required")
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
  print("OK " .. label)
end
local function wait(predicate, label, timeout)
  check(vim.wait(timeout or 8000, predicate, 20), label)
end

-- 必须让 lazy 应用 spec.opts：sidekick 的 setup 是「默认值 + 传入项」整体替换，
-- 再调一次 setup 会把本机配置冲掉。这里只加载插件，然后直接注入假工具。
require("lazy").load({ plugins = { "sidekick.nvim" } })
wait(function()
  return package.loaded["sidekick"] ~= nil
end, "sidekick loaded through lazy")
local Config = require("sidekick.config")
check(Config.cli.win.layout == "right", "panel stays a right-side split (upstream default)")
check(vim.api.nvim_get_hl(0, { name = "SidekickChat" }).link == "Normal", "panel highlight links to Normal")
check(Config.cli.tools.pi ~= nil, "pi tool definition is still available")
Config.cli.tools.nvim_panel_probe = { cmd = { "sh", "-c", "sleep 120" } }
local cli = require("sidekick.cli")
local terminals = require("sidekick.cli.terminal")

local ok, err = xpcall(function()
  cli.toggle("nvim_panel_probe")
  wait(function()
    return #terminals.sessions() > 0
  end, "panel session created")

  local session = terminals.sessions()[1]
  check(session.win and vim.api.nvim_win_is_valid(session.win), "panel window exists")
  local config = vim.api.nvim_win_get_config(session.win)
  check(config.relative == "", "panel is a split, as configured")
  local winhighlight = vim.wo[session.win].winhighlight
  check(winhighlight:find("Normal:SidekickChat", 1, true) ~= nil, "panel maps Normal to SidekickChat")
  -- 面板区域必须没有背景色：未定义 SidekickChat 时 Neovim 会退回 UI 默认背景（实心块）。
  local resolved = vim.api.nvim_get_hl(0, { name = "SidekickChat" })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  check(resolved.bg == nil and normal.bg == nil, "neither SidekickChat nor Normal forces a background")

  cli.toggle("nvim_panel_probe")
  wait(function()
    return not session:is_open()
  end, "toggle hides the panel")
  check(session:is_running(), "hiding keeps the CLI process alive")

  cli.toggle("nvim_panel_probe")
  wait(function()
    return session:is_open()
  end, "toggle shows the panel again")

  local job = session.job
  cli.close()
  wait(function()
    return not session:win_valid()
  end, "close removes the panel window")
  check(job and vim.fn.jobwait({ job }, 3000)[1] ~= -1, "close stops the CLI process")
end, debug.traceback)

for _, session in ipairs(terminals.sessions()) do
  if session.job then
    pcall(vim.fn.jobstop, session.job)
  end
end
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("PASS " .. checks .. " sidekick panel assertions")
vim.cmd("qa!")
