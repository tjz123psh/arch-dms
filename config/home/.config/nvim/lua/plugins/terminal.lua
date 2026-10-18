-- 独立终端 1/2/3；从浮窗切分屏前先回到普通窗口，退出后保留输出。
local function toggle(id, size, direction)
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative == "" then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end
  require("toggleterm").toggle(id, size, nil, direction)
end

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = "ToggleTerm",
  opts = {
    size = 20,
    shading_factor = 2,
    direction = "float",
    close_on_exit = false,
    float_opts = { border = "rounded" },
  },
  keys = {
    {
      "<leader>tt",
      function()
        toggle(1, 20, "float")
      end,
      desc = "切换浮动终端",
    },
    {
      "<leader>th",
      function()
        toggle(2, 15, "horizontal")
      end,
      desc = "水平分割终端",
    },
    {
      "<leader>tv",
      function()
        toggle(3, math.max(30, math.min(80, math.floor(vim.o.columns * 0.45))), "vertical")
      end,
      desc = "垂直分割终端",
    },
  },
}
