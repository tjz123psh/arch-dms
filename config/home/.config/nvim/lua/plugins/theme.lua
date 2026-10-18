-- 主题配色：catppuccin

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false, -- 立即加载（主题必须在启动时加载）
  priority = 1000, -- 高优先级，确保在其他插件之前加载

  opts = {
    flavour = "mocha", -- 深色风味
    transparent_background = true, -- kitty 终端已配 background_opacity，Neovim 不设背景色即可透出桌面
    term_colors = true, -- 让终端模拟器的颜色也匹配主题

    integrations = {
      treesitter = true, -- 语法高亮
      render_markdown = true, -- Markdown 编辑区美化（不使用整行背景）
      native_lsp = { enabled = true }, -- LSP 语义高亮
      blink_cmp = true, -- 补全菜单 blink.cmp
      indent_blankline = { enabled = true }, -- 缩进线
      lualine = { enabled = true }, -- 状态栏
      alpha = true, -- 欢迎页
      mason = true, -- Mason UI
      neotree = true, -- 文件树
      noice = true, -- UI 美化
      dap = true, -- 调试器
      dap_ui = true, -- 调试界面
      which_key = true, -- 快捷键提示
      snacks = true,
      flash = true,
      notify = true,
    },
  },

  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin") -- 应用主题

    local function neutralize_unnecessary_tag()
      vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})
    end
    neutralize_unnecessary_tag()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("theme_diagnostic_tags", { clear = true }),
      callback = neutralize_unnecessary_tag,
      desc = "诊断 tag（Unnecessary）不重绘文字颜色",
    })
  end,
}
