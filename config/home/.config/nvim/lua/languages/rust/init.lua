return {
  lsp = {
    rust_analyzer = {
      settings = {
        ["rust-analyzer"] = {
          check = { command = "clippy" },
          procMacro = { enable = true },
        },
      },
    },
  },
  lsp_enabled = {
    rust_analyzer = function()
      if vim.fn.executable("rustc") == 1 and vim.fn.executable("cargo") == 1 then
        return true
      end

      vim.schedule(function()
        vim.notify(
          "Rust 工具链未安装，已跳过 rust-analyzer。安装 rust 后重新打开项目即可。",
          vim.log.levels.WARN
        )
      end)
      return false
    end,
  },
  tools = { "rust-analyzer", "codelldb" },
  treesitter = { parsers = { "rust" }, filetypes = { "rust" }, indent = { "rust" } },
  -- rustfmt 由系统 Rust 工具链提供，不加入 Mason 安装清单。
  formatters = { rust = { "rustfmt" } },
  dap = {
    adapters = { codelldb = require("languages.shared.codelldb") },
    configurations = {
      rust = {
        {
          name = "启动调试（cargo 项目）",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/target/debug/", "file")
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
