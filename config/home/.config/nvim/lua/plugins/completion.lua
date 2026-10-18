-- 补全引擎：blink.cmp

return {
  "saghen/blink.cmp",
  version = "v1.*",
  lazy = false, -- 立即加载，确保补全始终可用
  dependencies = { "rafamadriz/friendly-snippets" },

  opts = {
    keymap = {
      preset = "default",
      ["<CR>"] = { "accept", "fallback" }, -- 回车选中当前项
      ["<Tab>"] = { "accept", "snippet_forward", "fallback" }, -- 选中补全或跳到下一片段占位符
      ["<S-Tab>"] = { "snippet_backward", "fallback" }, -- 跳到上一片段占位符
      ["<C-n>"] = { "select_next", "fallback" }, -- Ctrl+n 选择下一项
      ["<C-p>"] = { "select_prev", "fallback" }, -- Ctrl+p 选择上一项
      ["<C-e>"] = { "hide", "fallback" }, -- 关闭补全
      ["<C-u>"] = { "scroll_documentation_up", "fallback" }, -- 文档上翻
      ["<C-d>"] = { "scroll_documentation_down", "fallback" }, -- 文档下翻
    },

    sources = {
      default = { "lsp", "snippets", "buffer", "path" },
    },

    snippets = { preset = "default" },

    completion = {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 800, -- 上游默认 500ms，小窗里一停就弹会挡代码
        window = { border = "rounded", max_height = 12, desired_min_width = 40 },
      },
      menu = {
        border = "rounded",
        draw = {
          columns = {
            { "label", "label_description", gap = 1 },
            { "kind_icon" },
          },
        },
      },
    },

    appearance = {
      nerd_font_variant = "mono",
    },
  },
}
