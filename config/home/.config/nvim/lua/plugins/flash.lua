-- Flash 跳转：闪光标速移动

return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {
    modes = {
      search = { enabled = true },
    },
  },
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump()
      end,
      desc = "Flash 跳转",
    },
    {
      "S",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter 选择",
    },
  },
}
