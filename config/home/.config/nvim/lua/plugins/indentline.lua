-- 缩进线：indent-blankline.nvim

return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = "VeryLazy",

  opts = {
    indent = { char = "│" }, -- 缩进线的样式字符
    scope = { enabled = false }, -- 不显示作用域高亮（避免太花哨）
  },
}
