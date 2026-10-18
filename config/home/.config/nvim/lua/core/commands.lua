-- 自定义命令

vim.api.nvim_create_user_command("A", function()
  local ok, err = pcall(vim.cmd, "Alpha")
  if not ok then
    vim.notify("打开欢迎页失败: " .. tostring(err), vim.log.levels.ERROR)
  end
end, { force = true, desc = "打开欢迎页" })

-- 键盘与 bufferline 共用：保留分屏和未保存内容确认。
vim.api.nvim_create_user_command("BufDelete", function(p)
  local buf = tonumber(p.args)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.bufdelete then
    snacks.bufdelete(buf)
    return
  end
  vim.cmd("bdelete" .. (buf and (" " .. buf) or ""))
end, { nargs = "?", desc = "关闭缓冲区（保留分屏布局）" })

vim.api.nvim_create_user_command("CheatSheet", function()
  require("core.ui.cheatsheet").show()
end, { desc = "快捷键速查浮窗" })

require("core.projects").setup()
