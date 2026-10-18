-- Neovim 配置入口文件

vim.g.mapleader = " "

vim.g.maplocalleader = "\\"

require("core")

require("languages").setup()

require("core.lazy")

if vim.g.neovide then
  require("core.ui.neovide")
end
