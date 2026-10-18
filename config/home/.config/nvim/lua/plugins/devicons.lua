-- 文件图标：nvim-web-devicons 的缺口补齐

return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override = {
      properties = { icon = vim.fn.nr2char(0xE615), color = "#89b4fa", name = "Properties" },
      gotmpl = { icon = vim.fn.nr2char(0xE627), color = "#00ADD8", name = "Gotmpl" },
    },
  },
}
