-- 启动欢迎页：alpha-nvim

return {
  "goolord/alpha-nvim",
  event = vim.fn.argc() == 0 and "VimEnter" or nil,
  cmd = "Alpha",

  opts = function()
    local dashboard = require("alpha.themes.dashboard")

    local logo = {
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
    }
    dashboard.section.header.val = vim.o.columns >= 58 and logo or { "NEOVIM" }

    local config_search = "<cmd>lua require('snacks').picker.files({ cwd = vim.fn.stdpath('config') })<cr>"
    dashboard.section.buttons.val = {
      dashboard.button("f", "  查找文件", "<cmd>lua require('snacks').picker.files()<cr>"),
      dashboard.button("r", "  最近文件", "<cmd>lua require('snacks').picker.recent()<cr>"),
      dashboard.button("c", "  Neovim 配置", config_search),
      dashboard.button("p", "  项目列表", "<cmd>Projects<cr>"),
      dashboard.button("n", "  新建文件", "<cmd>ene <bar> startinsert<cr>"),
      dashboard.button("q", "  退出", "<cmd>qa<cr>"),
    }

    local version = vim.version()
    local cwd = vim.o.columns >= 80 and vim.fn.getcwd() or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    dashboard.section.footer.val = {
      "",
      string.format("  Neovim %d.%d.%d  |  %s  ", version.major, version.minor, version.patch, cwd),
    }
    dashboard.section.footer.opts.hl = "Type"

    for _, btn in ipairs(dashboard.section.buttons.val) do
      btn.opts.hl = "Label"
      btn.opts.hl_shortcut = "Keyword"
    end

    dashboard.opts.layout = {
      { type = "padding", val = 3 },
      dashboard.section.header,
      { type = "padding", val = 2 },
      dashboard.section.buttons,
      { type = "padding", val = 1 },
      dashboard.section.footer,
    }

    return dashboard.opts
  end,
}
