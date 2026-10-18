-- snacks.nvim：全机唯一的选择器 / 输入框提供者
local input_boxes = require("core.ui.input")

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,

    config = function(_, opts)
      do
        local dwin = require("snacks.picker.config.defaults").defaults.win
        -- 窗口键表是整体替换；复制默认键，只改 Esc 一次取消。
        opts.picker.win = {
          input = {
            keys = vim.tbl_extend("force", vim.deepcopy(dwin.input.keys), {
              ["<Esc>"] = { "cancel", mode = { "i", "n" } },
            }),
          },
        }
      end

      require("snacks").setup(opts)

      require("core.ui").setup()

      local layouts = require("snacks.picker.config.layouts")
      layouts.picker_compact = vim.tbl_deep_extend("force", vim.deepcopy(layouts.select), {
        hidden = { "preview" },
        config = function(layout)
          local spec = layout.layout or {}
          local h = spec.height
          local outer
          if type(h) == "number" and h > 0 and h < 1 then
            outer = math.floor(vim.o.lines * h) - 2
          elseif type(h) == "number" then
            outer = h
          else
            outer = math.floor(vim.o.lines * 0.5) - 2
          end
          outer = math.max(3, outer)
          local inner = math.max(2, outer - 2)
          for _, child in ipairs(spec) do
            if child.win == "list" then
              child.height = math.max(2, inner - 2)
            end
          end
          return layout
        end,
        layout = {
          min_width = 40,
          max_width = 110,
          width = function()
            return math.max(40, math.min(110, math.floor(vim.o.columns * 0.55)))
          end,
          height = 0.4,
          min_height = 2,
          title = " {title} {live} {flags} ",
          title_pos = "center",
        },
      })

      -- 数字子节点不能从 select 深合并；每次 resize 独立构造整棵布局。
      layouts.grep_split = {
        hidden = {},
        config = function(layout)
          local width = math.max(1, math.min(150, math.floor(vim.o.columns * 0.8), vim.o.columns - 4))
          local height = math.max(6, math.min(36, math.floor(vim.o.lines * 0.75), vim.o.lines - 4))
          local box = {
            width = width,
            height = height,
            border = "rounded",
            backdrop = false,
            title = " {title} {live} {flags} ",
            title_pos = "center",
          }
          if vim.o.columns >= 120 then
            local left = math.floor(width / 2)
            box.box = "horizontal"
            box[1] = {
              box = "vertical",
              border = "none",
              width = left,
              height = height,
              { win = "input", height = 1, border = "bottom" },
              { win = "list", height = height - 2, border = "none" },
            }
            box[2] = { win = "preview", title = " {preview} ", border = "left", width = width - left - 1 }
          else
            local list_height = math.max(2, math.floor((height - 3) / 2))
            box.box = "vertical"
            box[1] = { win = "input", height = 1, border = "bottom" }
            box[2] = { win = "list", height = list_height, border = "none" }
            box[3] = {
              win = "preview",
              title = " {preview} ",
              border = "top",
              height = height - list_height - 3,
            }
          end
          layout.layout = box
          return layout
        end,
      }

      -- ui.select 会自行注入布局，保留调用者配置并按实际条目数收缩。
      local wrapped_target = nil
      local function wrap_ui_select()
        local current = vim.ui.select
        if current == nil or current == wrapped_target then
          return
        end
        local info = debug.getinfo(current, "S")
        if not (info and info.short_src or ""):match("snacks") then
          return
        end
        vim.ui.select = function(items, sel_opts, on_choice)
          sel_opts = vim.deepcopy(sel_opts or {})
          local snacks = sel_opts.snacks or {}
          local prev_cfg = snacks.layout and snacks.layout.config
          sel_opts.snacks = vim.tbl_deep_extend("force", snacks, {
            layout = {
              preset = "picker_compact",
              config = function(layout)
                if prev_cfg then
                  layout = prev_cfg(layout) or layout
                end
                for _, child in ipairs(layout.layout or {}) do
                  if child.win == "list" then
                    child.height = math.max(math.min(#items, math.floor(vim.o.lines * 0.8) - 10), 2)
                  end
                end
                return layout
              end,
            },
          })
          return current(items, sel_opts, on_choice)
        end
        wrapped_target = vim.ui.select -- 记下我们这层，避免重复包装
      end
      vim.api.nvim_create_autocmd("UIEnter", {
        group = vim.api.nvim_create_augroup("SnacksUiSelectHeightFix", { clear = true }),
        callback = wrap_ui_select,
      })
      wrap_ui_select() -- 已有 UI 时立即包装；完整配置重载请重启 Neovim
    end,

    opts = {
      picker = {
        enabled = true,
        layout = {
          cycle = true,
          preset = "picker_compact",
        },
        sources = {
          grep = { layout = { preset = "grep_split" } },
        },
        ui_select = true,
      },

      notifier = { enabled = false },
      dashboard = { enabled = false },
      terminal = { enabled = false },
      input = {
        enabled = true,
        win = { row = input_boxes.center_row, width = input_boxes.width },
      },
      explorer = { enabled = false },
    },
  },
}
