-- 文件树：neo-tree.nvim

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "打开/关闭文件树" },
  },
  opts = {
    popup_border_style = "rounded",
    use_popups_for_input = false, -- 走 vim.ui.input，由 snacks 输入框接管（全机统一风格）
    window = {
      position = "left",
      width = function()
        return math.max(20, math.min(35, math.floor(vim.o.columns * 0.4)))
      end,
      mappings = {
        ["<cr>"] = "open",
        ["o"] = "open",
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      bind_to_cwd = true,
      window = {
        mappings = {
          ["h"] = "navigate_up",
          ["l"] = "set_root",
          ["r"] = "rename",
          ["m"] = "move",
          ["Z"] = "expand_all_subnodes", -- 递归展开光标所在节点下的所有子节点
          ["."] = false,
        },
      },
    },
    default_component_configs = {
      indent = {
        with_markers = true,
        with_expanders = true,
        padding = 1,
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        padding = " ",
      },
      git_status = {
        symbols = {
          added = "✚",
          modified = "",
          deleted = "✖",
        },
      },
    },
  },
}
