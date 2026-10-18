return {
  lsp = {
    gopls = {
      settings = {
        gopls = {
          gofumpt = true,
          analyses = { unusedparams = true, unreachable = true },
          staticcheck = true,
        },
      },
    },
  },
  tools = { "gopls", "delve" },
  treesitter = { parsers = { "go" }, filetypes = { "go" }, indent = { "go" } },
  filetypes = { extension = { gotmpl = "gotmpl" } },
  -- 不配置外部 formatter，保持使用启用 gofumpt 的 gopls fallback。
  dap = {
    adapters = {
      delve = function(callback)
        callback({
          type = "server",
          port = "${port}",
          executable = {
            command = vim.fn.stdpath("data") .. "/mason/bin/dlv",
            args = { "dap", "-l", "127.0.0.1:${port}" },
          },
        })
      end,
    },
    configurations = {
      go = {
        {
          name = "启动调试",
          type = "delve",
          request = "launch",
          program = "${workspaceFolder}",
          cwd = "${workspaceFolder}",
        },
      },
    },
  },
}
