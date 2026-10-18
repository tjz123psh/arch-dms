return {
  lsp = { clangd = require("languages.shared.clangd") },
  tools = { "clangd", "codelldb", "clang-format" },
  treesitter = { parsers = { "cpp" }, filetypes = { "cpp" }, indent = { "cpp" } },
  formatters = { cpp = { "clang-format" } },
  buffer_options = { cpp = { tabstop = 4, shiftwidth = 4 } },
  dap = {
    adapters = { codelldb = require("languages.shared.codelldb") },
    configurations = {
      cpp = {
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
            local file = vim.fn.expand("%:t:r") -- 去掉目录和扩展名
            return vim.fn.getcwd() .. "/" .. file
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
        {
          name = "附加到进程",
          type = "codelldb",
          request = "attach",
          pid = function()
            return tonumber(vim.fn.input("进程 PID: "))
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      },
    },
  },
}
