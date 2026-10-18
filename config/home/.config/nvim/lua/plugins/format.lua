return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  opts = function()
    local opts = require("languages").conform()
    local on_save = opts.format_on_save
    opts.format_on_save = function(buf)
      if on_save[vim.bo[buf].filetype] == false then
        return nil
      end
      return { timeout_ms = 2000, lsp_format = "fallback" }
    end
    return opts
  end,
  keys = {
    {
      "<leader>F",
      function()
        require("conform").format({ async = false, timeout_ms = 2000, lsp_format = "fallback" })
      end,
      desc = "手动格式化当前文件",
    },
  },
}
