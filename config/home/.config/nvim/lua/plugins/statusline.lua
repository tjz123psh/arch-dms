-- 状态栏：lualine.nvim

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "catppuccin/nvim" },
  event = "UIEnter",

  opts = function()
    local ok, theme = pcall(require, "lualine.themes.catppuccin-mocha")
    if ok and type(theme) == "table" then
      for _, mode in pairs(theme) do
        if type(mode) == "table" then
          mode.c = vim.tbl_extend("force", mode.c or {}, { bg = "#181825" })
        end
      end
    end
    return {
      options = {
        theme = ok and theme or "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
        disabled_filetypes = { "alpha" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          {
            "filename",
            file_status = true,
            path = 1,
            symbols = { modified = " ●", readonly = " " },
          },
        },
        lualine_x = {
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            colored = true,
            update_in_insert = false,
            symbols = { error = " 󰅚 ", warn = " 󰀪 ", info = " 󰋽 ", hint = " 󰌶 " },
          },
          { "lsp_status", icon = "", show_name = true },
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
      extensions = { "neo-tree" },
    }
  end,
}
