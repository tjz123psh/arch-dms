-- 自动命令（Autocmds）

local augroup = vim.api.nvim_create_augroup("core", { clear = true })

vim.api.nvim_create_autocmd("InsertEnter", {
  group = augroup,
  callback = function()
    if vim.o.hlsearch then
      vim.o.hlsearch = false
    end
  end,
})

local function is_savable(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end

  local bo = vim.bo[buf]
  if bo.buftype ~= "" or not bo.modifiable or bo.readonly then
    return false
  end

  return vim.api.nvim_buf_get_name(buf) ~= "" and bo.modified
end

-- 直接 Ex 退出交给原生解析；Lua/ZQ 退出使用显式丢弃保护。
local QUIT_COMMANDS = {
  quit = true,
  qall = true,
  quitall = true,
  cquit = true,
  wq = true,
  wqall = true,
  exit = true,
  xit = true,
  xall = true,
}
local function quit_commands(line)
  local commands = {}
  while line ~= "" do
    local ok, cmd = pcall(vim.api.nvim_parse_cmd, line, {})
    if not ok then
      break -- 无效命令不应让自动命令本身报错。
    end
    if QUIT_COMMANDS[cmd.cmd] then
      commands[#commands + 1] = {
        name = cmd.cmd,
        discard = cmd.cmd == "cquit" or (cmd.bang and (cmd.cmd == "quit" or cmd.cmd == "qall" or cmd.cmd == "quitall")),
      }
    end
    local nextcmd = cmd.nextcmd or ""
    if nextcmd == line then
      break
    end
    line = nextcmd
  end
  return commands
end

local pending_quits = {}
local discard_window -- 本次正在关闭的窗口；WinClosed 后不再阻止剩余会话的保存。
local discard_exit = false -- 最后一次 QuitPre 的意图，供进程退出时的 VimLeavePre 使用。
local protected_discard = 0 -- ZQ 的同步调用范围；即使其它自动命令 vim.wait，也不能提前清除。
local function clear_quit_state()
  pending_quits = {}
  discard_window = nil
  discard_exit = false
end

vim.api.nvim_create_autocmd("CmdlineEnter", {
  group = augroup,
  callback = clear_quit_state,
  desc = "新命令不继承旧的退出意图",
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = augroup,
  pattern = ":", -- 搜索命令行里的 q! 不是退出命令。
  callback = function()
    if not vim.v.event.abort then
      pending_quits = quit_commands(vim.fn.getcmdline())
    end
  end,
  desc = "按原生语法记录退出命令及丢弃意图",
})
vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup,
  callback = function(ev)
    if tonumber(ev.match) == discard_window then
      discard_window = nil
    end
  end,
  desc = "目标窗口关闭后，立即恢复其余窗口的自动保存",
})
-- schedule 会在 vim.wait 内提前执行；只能在命令真正结束后清理意图。
vim.api.nvim_create_autocmd("SafeState", {
  group = augroup,
  callback = function()
    if protected_discard == 0 then
      clear_quit_state()
    end
  end,
  desc = "命令执行完且回到输入等待时清理退出状态（含失败的退出）",
})

local saving = false -- 重入保护：写盘时可能触发 BufLeave/退出类事件

local function write_current()
  vim.cmd("silent! lockmarks write")
end

local function autosave_current_buf()
  if vim.g.core_autosave == false or saving then
    return
  end
  if discard_window or protected_discard > 0 then
    return
  end

  if is_savable(vim.api.nvim_get_current_buf()) then
    saving = true
    write_current()
    saving = false
  end
end

-- 退出保存所有已修改缓冲区，不能只保存当前窗口。
local function autosave_all_bufs()
  if vim.g.core_autosave == false or saving then
    return
  end
  saving = true
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_savable(buf) then
      vim.api.nvim_buf_call(buf, write_current)
    end
  end
  saving = false
end

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  group = augroup,
  desc = "自动保存当前普通文件缓冲区",
  callback = autosave_current_buf,
})

vim.api.nvim_create_autocmd("QuitPre", {
  group = augroup,
  callback = function()
    local intent = protected_discard == 0 and table.remove(pending_quits, 1) or nil
    discard_exit = protected_discard > 0 or (intent and intent.discard) or false
    discard_window = discard_exit and vim.api.nvim_get_current_win() or nil
    if not discard_exit then
      autosave_all_bufs()
    end
  end,
  desc = "普通退出保存全部修改；丢弃退出不自动写盘",
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  callback = function()
    if pending_quits[1] and pending_quits[1].name == "cquit" then
      discard_exit = true
    end
    if not discard_exit and protected_discard == 0 then
      autosave_all_bufs()
    end
  end,
  desc = "进程退出时保留本次明确的保存/丢弃语义",
})

return {
  quit_without_save = function()
    protected_discard = protected_discard + 1
    local ok, err = pcall(vim.cmd.quit, { bang = true })
    protected_discard = protected_discard - 1
    discard_window, discard_exit = nil, false
    if not ok then
      error(err, 0)
    end
  end,
}
