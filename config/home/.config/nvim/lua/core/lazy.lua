-- lazy.nvim 插件管理器配置

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local entry_ok = vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") or vim.uv.fs_stat(lazypath .. "/lua/lazy.lua")
if not entry_ok then
  if vim.uv.fs_stat(lazypath) then
    -- 残缺目录可能含待恢复内容，保留而非自动删除。
    local saved = lazypath .. ".incomplete-" .. tostring(vim.fn.getpid())
    assert(not vim.uv.fs_lstat(saved), "lazy.nvim 备份路径已存在: " .. saved)
    local ok, err = vim.uv.fs_rename(lazypath, saved)
    assert(ok, "无法保留残缺 lazy.nvim: " .. tostring(err))
  end
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  assert(vim.v.shell_error == 0, "安装 lazy.nvim 失败: " .. output)
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  rocks = { enabled = false }, -- 不用 rocks 生态插件，清 checkhealth 警告
  defaults = {
    version = false, -- 不锁定版本，随时更新
  },
  install = {
    colorscheme = { "catppuccin" }, -- 安装插件时用的临时主题
  },
  -- 启动不执行更新检查；需要时手动 :Lazy check。
  checker = {
    enabled = false,
    notify = false,
  },
  change_detection = {
    notify = false, -- 配置文件变更时不提示
  },
  performance = {
    rtp = {
      disabled_plugins = { -- 禁用 Neovim 内置的不常用插件
        "gzip",
        "tarPlugin",
        "zipPlugin",
        "tohtml",
        "tutor",
      },
    },
  },
})
