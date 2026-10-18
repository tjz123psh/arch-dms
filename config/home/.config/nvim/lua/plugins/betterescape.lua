-- 快捷退出插入模式：better-escape

return {
  "nvim-zh/better-escape.vim",
  event = "InsertEnter",
  config = function()
    vim.g.better_escape_shortcut = "jk"
    vim.g.better_escape_interval = 200
  end,
}
