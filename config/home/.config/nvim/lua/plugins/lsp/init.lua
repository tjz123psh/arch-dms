return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    "williamboman/mason.nvim",
    "saghen/blink.cmp",
  },
  opts = function()
    local languages = require("languages")
    return { servers = languages.servers(), enabled = languages.lsp_enabled() }
  end,
  config = function(_, opts)
    local capabilities = require("blink.cmp").get_lsp_capabilities()
    for name, config in pairs(opts.servers) do
      local enabled = opts.enabled[name]
      if not enabled or enabled() then
        config.capabilities = vim.tbl_deep_extend("force", capabilities, config.capabilities or {})
        config.on_attach = require("languages.shared.lsp")
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end
    end
  end,
}
