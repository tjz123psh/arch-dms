return {
  lsp = {
    -- 由消费者读取配置时再取 runtimepath，避免入口 require 太早捕获插件库路径。
    lua_ls = function()
      return {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim", "jit" } },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file("lua", true),
            },
            telemetry = { enable = false },
          },
        },
      }
    end,
  },
  tools = { "lua-language-server", "stylua" },
  treesitter = { parsers = { "lua" }, filetypes = { "lua" }, indent = { "lua" } },
  formatters = { lua = { "stylua" } },
  buffer_options = { lua = { tabstop = 2, shiftwidth = 2 } },
  plugins = {
    -- 只在编辑 Lua 时加载，不作为全局 LSP 的 eager 依赖。
    { "folke/lazydev.nvim", ft = "lua", opts = {} },
  },
  commands = {
    R = {
      callback = function()
        if vim.bo.filetype ~= "lua" then
          vim.notify(":R 只能在 .lua 文件中使用", vim.log.levels.WARN)
          return
        end
        -- 只执行磁盘文件，不清 require 缓存，也不重新应用插件配置表。
        vim.cmd.luafile(vim.fn.expand("%:p"))
      end,
      opts = { force = true, desc = "执行当前磁盘 Lua 文件（非完整配置重载）" },
    },
  },
}
