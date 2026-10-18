-- UI 增强：noice.nvim

local input_boxes = require("core.ui.input")

return {
  "folke/noice.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
    {
      "rcarriga/nvim-notify",
      opts = {
        timeout = 2500,
        stages = "fade_in_slide_out",
        background_colour = "#1e1e2e",
      },
      config = function(_, opts)
        local notify = require("notify")
        notify.setup(opts)
        vim.notify = notify
      end,
    },
  },

  opts = {
    views = {
      cmdline_popup = {
        position = { row = "50%", col = "50%" },
        size = { width = "auto", min_width = input_boxes.noice_min_width(), height = "auto" },
        border = { style = "rounded" },
      },
      messages = {
        view = "popup",
        position = { row = "40%", col = "50%" },
        size = { width = "auto", min_width = 40, max_width = 100, height = "auto", max_height = 20 },
        border = { style = "rounded" },
      },
    },

    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      format = { input = { title = " 输入 " } },
    },

    messages = {
      enabled = true,
      view = "notify",
      view_error = "notify",
      view_warn = "notify",
    },

    popupmenu = {
      enabled = true,
      backend = "nui",
    },

    notify = {
      enabled = true,
      view = "mini",
    },

    lsp = {
      progress = {
        enabled = true,
        view = "notify",
        format = "lsp",
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },

    routes = {
      { filter = { event = "msg_show", kind = "search_count" }, opts = { skip = true } },
      { filter = { event = "lsp", kind = "progress", find = "jdtls" }, opts = { skip = true } },
    },
  },
}
