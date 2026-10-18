return {
  lsp = { clangd = require("languages.shared.clangd") },
  tools = { "clangd", "codelldb", "clang-format" },
  treesitter = { parsers = { "c" }, filetypes = { "c" }, indent = { "c" } },
  formatters = { c = { "clang-format" } },
  buffer_options = { c = { tabstop = 4, shiftwidth = 4 } },
  dap = {
    adapters = { codelldb = require("languages.shared.codelldb") },
    configurations = {
      c = {
        {
          name = "启动调试（输路径）",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
        {
          name = "启动调试（取当前文件名）",
          type = "codelldb",
          request = "launch",
          program = function()
            local file = vim.fn.expand("%:t:r")
            return vim.fn.getcwd() .. "/" .. file
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      },
    },
  },
}
