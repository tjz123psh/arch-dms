-- 标签栏（缓冲区列表）：bufferline.nvim

return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "catppuccin/nvim",
  },
  event = "VeryLazy",
  keys = {
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "切换到上一个缓冲区" },
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "切换到下一个缓冲区" },
  },
  opts = function()
    local SOLID_BG, SOLID_BG_ACTIVE = "#181825", "#1e1e2e"
    local BORDER, ACCENT, MODIFIED, RED = "#7f849c", "#89b4fa", "#f9e2af", "#f38ba8"

    local highlights
    local ok, bufferline_theme = pcall(require, "catppuccin.special.bufferline")
    if ok then
      local upstream = bufferline_theme.get_theme()
      highlights = function()
        local hl = upstream()
        for name, spec in pairs(hl) do
          if type(spec) == "table" and spec.bg == "NONE" then
            spec.bg = name:find("_selected", 1, true) and SOLID_BG_ACTIVE or SOLID_BG
          end
        end
        for _, name in ipairs({
          "buffer_visible",
          "separator",
          "separator_visible",
          "separator_selected",
          "offset_separator",
          "close_button",
          "close_button_visible",
        }) do
          if hl[name] then
            hl[name].fg = (name == "buffer_visible") and "#a6adc8" or BORDER
          end
        end
        if hl.indicator_selected then
          hl.indicator_selected = { fg = ACCENT, bg = SOLID_BG_ACTIVE, bold = true }
        end
        if hl.indicator_visible then
          hl.indicator_visible = { fg = BORDER, bg = SOLID_BG }
        end
        if hl.close_button_selected then
          hl.close_button_selected.fg = RED
        end
        for _, name in ipairs({ "modified", "modified_visible", "modified_selected" }) do
          if hl[name] then
            hl[name].fg = MODIFIED
          end
        end
        return hl
      end
    end

    return {
      highlights = highlights,
      options = {
        mode = "buffers",
        numbers = "none",
        always_show_bufferline = false,
        close_command = "BufDelete %d",
        right_mouse_command = "BufDelete %d",
        indicator = {
          style = "icon",
          icon = "▎",
        },
        buffer_close_icon = "󰅖",
        modified_icon = "●",
        left_trunc_marker = "",
        right_trunc_marker = "",
        separator_style = "thin",
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diagnostics)
          local parts = {}
          for _, item in ipairs({
            { "error", "󰅚" },
            { "warning", "󰀪" },
            { "info", "󰋽" },
            { "hint", "󰌶" },
          }) do
            local count = diagnostics[item[1]] or 0
            if count > 0 then
              table.insert(parts, item[2] .. " " .. count)
            end
          end
          return #parts > 0 and " " .. table.concat(parts, " ") or ""
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "文件树",
            highlight = "Directory",
            text_align = "left",
            padding = 1,
          },
        },
      },
    }
  end,
}
