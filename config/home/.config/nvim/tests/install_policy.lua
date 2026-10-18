-- 完整配置启动前用 --cmd 'luafile tests/install_policy.lua' 注入；仅测试进程内拦截下载/安装。
local data = vim.env.HOME .. "/.local/share/nvim"
vim.opt.rtp:append(data .. "/lazy/mason.nvim")
local registry = require("mason-registry")
local Package = require("mason-core.package")
local manual = false
local refreshes, updates, writes = 0, 0, 0
registry.refresh = function(callback)
  refreshes = refreshes + 1
  if callback then
    callback(true, {})
  end
  return true, {}
end
registry.update = function(callback)
  updates = updates + 1
  if callback then
    callback(true, {})
  end
end
local is_installed = Package.is_installed
Package.is_installed = function(self, ...)
  if not manual then
    return false
  end -- 模拟缺失工具，证明启动不偷偷安装。
  return is_installed(self, ...)
end
Package.install = function()
  writes = writes + 1
  error("test blocks package installation")
end
Package.uninstall = function()
  writes = writes + 1
  error("test blocks package removal")
end
require("mason-core.platform").is_headless = false -- 覆盖 GUI 才执行 ensure_installed 的分支。
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = xpcall(function()
        assert(refreshes == 0 and updates == 0 and writes == 0, "startup attempted registry refresh/install")
        assert(not package.loaded["mason-lspconfig"], "installer loaded at startup")
        for _, cmd in ipairs({ "LspInstall", "LspUninstall", "MasonToolsInstall", "MasonToolsUpdate" }) do
          assert(vim.fn.exists(":" .. cmd) == 2, cmd .. " command missing")
        end
        for _, name in ipairs({ "clangd", "lua_ls", "gopls", "rust_analyzer", "lemminx" }) do
          assert(vim.lsp.is_enabled(name), name .. " no longer enabled")
        end
        manual = true
        local opts = require("lazy.core.plugin").values(
          require("lazy.core.config").plugins["mason-tool-installer.nvim"],
          "opts",
          false
        )
        local expected = {
          "clangd",
          "lua-language-server",
          "jdtls",
          "gopls",
          "rust-analyzer",
          "html-lsp",
          "css-lsp",
          "json-lsp",
          "yaml-language-server",
          "marksman",
          "lemminx",
        }
        for _, name in ipairs(expected) do
          assert(vim.tbl_contains(opts.ensure_installed, name), "bulk installer lost " .. name)
          assert(registry.has_package(name), "not a Mason package name: " .. name)
        end
        assert(opts.integrations["mason-lspconfig"] == false and opts.run_on_start == false)
        -- 本机清单已安装；仅运行检查，安装/删除均被上面的类方法拦截。
        vim.cmd.MasonToolsInstall()
        assert(
          vim.wait(1000, function()
            return refreshes > 0
          end, 10),
          "manual bulk install did not refresh"
        )
        assert(not package.loaded["mason-lspconfig"], "bulk tool names unexpectedly load alias integration")
        local before_update = refreshes
        local latest = Package.get_latest_version
        Package.get_latest_version = function(self)
          return self:get_installed_version()
        end
        vim.cmd.MasonToolsUpdate()
        assert(
          vim.wait(1000, function()
            return refreshes > before_update
          end, 10),
          "manual bulk update missing"
        )
        Package.get_latest_version = latest
        local api = require("mason.api.command")
        local installed, removed
        api.MasonInstall = function(names)
          installed = names
        end
        api.MasonUninstall = function(names)
          removed = names
        end
        require("mason.ui").set_view = function() end
        vim.cmd("LspInstall lua_ls")
        assert(
          vim.wait(1000, function()
            return installed ~= nil
          end, 10),
          "LspInstall handler not loaded"
        )
        assert(vim.deep_equal(installed, { "lua-language-server" }), "LspInstall alias mapping broken")
        local settings = require("mason-lspconfig.settings").current
        assert(
          #settings.ensure_installed == 0 and settings.automatic_enable == false,
          "manual entry reintroduced automatic installation"
        )
        vim.cmd("LspUninstall lua_ls")
        assert(vim.deep_equal(removed, { "lua-language-server" }), "LspUninstall alias mapping broken")
        assert(writes == 0, "test attempted real package writes")
        io.stderr:write("PASS startup refresh/install=0; manual bulk and LSP commands work; package writes=0\n")
      end, debug.traceback)
      if not ok then
        io.stderr:write(tostring(err) .. "\n")
        vim.cmd("cquit 1")
      else
        vim.cmd("qa!")
      end
    end, 200)
  end,
})
