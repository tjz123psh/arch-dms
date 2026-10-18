return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "williamboman/mason.nvim" },
  opts = function()
    return {
      run_on_start = false, -- 只保留手动安装/更新，启动不刷新注册表或下载。
      integrations = { ["mason-lspconfig"] = false },
      ensure_installed = require("languages").tools(),
    }
  end,
}
